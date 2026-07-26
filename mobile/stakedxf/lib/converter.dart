import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

typedef _ConvertNative = Int32 Function(
  Pointer<Utf8> input,
  Pointer<Utf8> output,
  Pointer<Utf8> err,
  Int32 errLen,
);
typedef _ConvertDart = int Function(
  Pointer<Utf8> input,
  Pointer<Utf8> output,
  Pointer<Utf8> err,
  int errLen,
);

class LayerInfo {
  const LayerInfo({
    required this.name,
    required this.entityCount,
    this.types = const {},
  });

  final String name;
  final int entityCount;
  final Map<String, int> types;

  factory LayerInfo.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['types'];
    final types = <String, int>{};
    if (rawTypes is Map) {
      rawTypes.forEach((key, value) {
        final n = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
        types['$key'] = n;
      });
    }
    return LayerInfo(
      name: json['name']?.toString() ?? '0',
      entityCount: (json['entity_count'] as num?)?.toInt() ??
          (json['entityCount'] as num?)?.toInt() ??
          0,
      types: types,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'entity_count': entityCount,
        if (types.isNotEmpty) 'types': types,
      };
}

class ConvertResult {
  ConvertResult({
    required this.outputPath,
    required this.stakeableCount,
    required this.message,
    this.proxyExploded = 0,
    this.layers = const [],
    this.emptyLayersRemoved = 0,
  });

  final String outputPath;
  final int stakeableCount;
  final String message;
  final int proxyExploded;
  final List<LayerInfo> layers;
  final int emptyLayersRemoved;

  ConvertResult copyWith({
    String? outputPath,
    int? stakeableCount,
    String? message,
    int? proxyExploded,
    List<LayerInfo>? layers,
    int? emptyLayersRemoved,
  }) {
    return ConvertResult(
      outputPath: outputPath ?? this.outputPath,
      stakeableCount: stakeableCount ?? this.stakeableCount,
      message: message ?? this.message,
      proxyExploded: proxyExploded ?? this.proxyExploded,
      layers: layers ?? this.layers,
      emptyLayersRemoved: emptyLayersRemoved ?? this.emptyLayersRemoved,
    );
  }
}

DynamicLibrary _openLib() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libstakedxf.so');
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isLinux) {
    final candidates = <String>[
      '/workspace/native/build/host/libstakedxf.so',
      p.join(Directory.current.path, 'native/build/host/libstakedxf.so'),
      p.join(Directory.current.path, '../../native/build/host/libstakedxf.so'),
      'libstakedxf.so',
    ];
    for (final path in candidates) {
      if (path == 'libstakedxf.so' || File(path).existsSync()) {
        try {
          return DynamicLibrary.open(path);
        } catch (_) {}
      }
    }
  }
  throw UnsupportedError(
    'Native converter not available on ${Platform.operatingSystem}',
  );
}

List<LayerInfo> parseLayersJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => LayerInfo.fromJson(Map<String, dynamic>.from(e)))
        .where((l) => l.entityCount > 0)
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Count modelspace entities per layer from an ASCII DXF (host / fallback).
List<LayerInfo> listLayersFromDxfText(String text) {
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final counts = <String, int>{};
  var inEntities = false;
  String? code;
  String? currentType;
  String currentLayer = '0';
  var countedCurrent = false;

  void finishEntity() {
    if (currentType == null) return;
    if (stakeableTypes.contains(currentType) &&
        currentType != 'VERTEX' &&
        currentType != 'SEQEND') {
      counts[currentLayer] = (counts[currentLayer] ?? 0) + 1;
    }
    currentType = null;
    currentLayer = '0';
    countedCurrent = false;
  }

  for (final line in lines) {
    final value = line.trim();
    if (!inEntities) {
      if (code == '2' && value == 'ENTITIES') {
        inEntities = true;
      }
      code = int.tryParse(value) != null ? value : null;
      continue;
    }
    if (code == '0') {
      if (value == 'ENDSEC') {
        finishEntity();
        break;
      }
      finishEntity();
      currentType = value;
      currentLayer = '0';
      countedCurrent = false;
    } else if (code == '8' && currentType != null && !countedCurrent) {
      currentLayer = value.isEmpty ? '0' : value;
    }
    code = int.tryParse(value) != null ? value : null;
  }

  final layers = counts.entries
      .map((e) => LayerInfo(name: e.key, entityCount: e.value))
      .toList()
    ..sort((a, b) {
      final byCount = b.entityCount.compareTo(a.entityCount);
      if (byCount != 0) return byCount;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return layers;
}

typedef ConvertProgressCallback = void Function(
  String stage,
  int percent,
  String message,
);

class NativeConverter {
  static const _linework = MethodChannel('com.stakedxf/linework');
  static const _progress = EventChannel('com.stakedxf/convert_progress');

  /// Convert DWG/DXF → Trimble stakeable DXF.
  ///
  /// On Android: starts a foreground-service keep-alive, runs DWG→DXF via
  /// LibreDWG in an isolate, then recovers Civil 3D proxy linework on a
  /// background Kotlin/Python worker (with staged progress).
  /// Empty layers are omitted; [ConvertResult.layers] lists layers with data.
  Future<ConvertResult> convertFile({
    required String inputPath,
    required String outputPath,
    ConvertProgressCallback? onProgress,
  }) async {
    final lower = inputPath.toLowerCase();
    var rawDxf = outputPath;
    StreamSubscription? progressSub;

    Future<void> notify(String stage, int percent, String message) async {
      onProgress?.call(stage, percent, message);
      if (Platform.isAndroid) {
        try {
          await _linework.invokeMethod<dynamic>('updateConvertGuard', {
            'stage': stage,
            'percent': percent,
            'message': message,
          });
        } catch (_) {}
      }
    }

    if (Platform.isAndroid) {
      try {
        await _linework.invokeMethod<dynamic>('startConvertGuard', {
          'message': 'Preparing conversion…',
        });
      } catch (_) {
        // Continue without FGS if the OEM blocks it; conversion still runs.
      }
      progressSub = _progress.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final type = event['type']?.toString();
          if (type == 'progress') {
            onProgress?.call(
              event['stage']?.toString() ?? 'convert',
              (event['percent'] as num?)?.toInt() ?? 0,
              event['message']?.toString() ?? '',
            );
          }
        }
      });
    }

    try {
      await notify('prepare', 2, 'Preparing conversion…');

      if (lower.endsWith('.dwg')) {
        rawDxf = '$outputPath.raw.dxf';
        await notify('dwg', 8, 'Reading DWG (LibreDWG)…');
        await compute(_dwgToDxfWorker, <String, String>{
          'input': inputPath,
          'output': rawDxf,
        });
        await notify('dwg', 30, 'DWG decoded — recovering linework…');
      } else if (lower.endsWith('.dxf')) {
        rawDxf = inputPath;
        await notify('dxf', 20, 'DXF selected — recovering linework…');
      } else {
        throw Exception('Choose a .dwg or .dxf file');
      }

      if (Platform.isAndroid) {
        final raw = await _linework.invokeMethod<dynamic>('recoverLinework', {
          'input': rawDxf,
          'output': outputPath,
        });
        if (raw is! Map) {
          throw Exception('Linework recovery returned nothing');
        }
        final recovered = Map<String, dynamic>.from(raw);
        final stakeable = (recovered['stakeable_count'] as num?)?.toInt() ?? 0;
        final proxyExploded =
            (recovered['proxy_exploded'] as num?)?.toInt() ?? 0;
        final layers = parseLayersJson(recovered['layers_json']?.toString());
        final message = recovered['message']?.toString() ??
            (stakeable > 0
                ? 'Recovered $stakeable stakeable entities on ${layers.length} layer(s)'
                : 'No stakeable linework found in this drawing.');
        await notify('done', 100, message);
        return ConvertResult(
          outputPath: outputPath,
          stakeableCount: stakeable,
          proxyExploded: proxyExploded,
          message: message,
          layers: layers,
          emptyLayersRemoved:
              (recovered['empty_layers_removed'] as num?)?.toInt() ?? 0,
        );
      }

      // Host / iOS fallback: text filter only (no proxy explode).
      await notify('filter', 50, 'Filtering stakeable entities…');
      final stakeable = await compute(_filterWorker, <String, String>{
        'input': rawDxf,
        'output': outputPath,
      });
      final layers = listLayersFromDxfText(File(outputPath).readAsStringSync());
      final message = stakeable > 0
          ? 'Ready for Trimble Access stakeout — ${layers.length} layer(s) with data'
          : 'No stakeable linework found in this drawing.';
      await notify('done', 100, message);
      return ConvertResult(
        outputPath: outputPath,
        stakeableCount: stakeable,
        message: message,
        layers: layers,
      );
    } finally {
      await progressSub?.cancel();
      if (Platform.isAndroid) {
        try {
          await _linework.invokeMethod<dynamic>('stopConvertGuard');
        } catch (_) {}
      }
      if (rawDxf != inputPath && rawDxf != outputPath) {
        try {
          File(rawDxf).deleteSync();
        } catch (_) {}
      }
    }
  }

  /// List non-empty layers in an existing converted DXF.
  Future<List<LayerInfo>> listLayers(String dxfPath) async {
    if (Platform.isAndroid) {
      final raw = await _linework.invokeMethod<dynamic>('listLayers', {
        'input': dxfPath,
      });
      if (raw is Map) {
        final layers =
            parseLayersJson(Map<String, dynamic>.from(raw)['layers_json']?.toString());
        if (layers.isNotEmpty) return layers;
      }
    }
    return listLayersFromDxfText(File(dxfPath).readAsStringSync());
  }

  /// Rewrite [inputPath] keeping only [layerNames], writing [outputPath].
  Future<ConvertResult> filterLayers({
    required String inputPath,
    required String outputPath,
    required Iterable<String> layerNames,
  }) async {
    final selected = layerNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (selected.isEmpty) {
      throw Exception('Select at least one layer');
    }

    if (Platform.isAndroid) {
      final raw = await _linework.invokeMethod<dynamic>('filterLayers', {
        'input': inputPath,
        'output': outputPath,
        'layers_json': jsonEncode(selected),
      });
      if (raw is! Map) {
        throw Exception('Layer filter returned nothing');
      }
      final recovered = Map<String, dynamic>.from(raw);
      final ok = recovered['ok'] == true ||
          recovered['ok']?.toString().toLowerCase() == 'true';
      final stakeable = (recovered['stakeable_count'] as num?)?.toInt() ?? 0;
      final layers = parseLayersJson(recovered['layers_json']?.toString());
      final message = recovered['message']?.toString() ??
          (ok
              ? 'Exported $stakeable entities on ${layers.length} selected layer(s)'
              : 'No entities on the selected layers');
      if (!ok && stakeable == 0) {
        throw Exception(message);
      }
      return ConvertResult(
        outputPath: outputPath,
        stakeableCount: stakeable,
        message: message,
        layers: layers,
      );
    }

    final stakeable = await compute(_filterLayersWorker, <String, dynamic>{
      'input': inputPath,
      'output': outputPath,
      'layers': selected,
    });
    final layers = listLayersFromDxfText(File(outputPath).readAsStringSync());
    return ConvertResult(
      outputPath: outputPath,
      stakeableCount: stakeable,
      message:
          'Exported $stakeable entities on ${layers.length} selected layer(s)',
      layers: layers,
    );
  }
}

void _dwgToDxfWorker(Map<String, String> args) {
  final input = args['input']!;
  final output = args['output']!;
  final lib = _openLib();
  final convert = lib.lookupFunction<_ConvertNative, _ConvertDart>(
    'stakedxf_convert',
  );
  final inputPtr = input.toNativeUtf8();
  final outputPtr = output.toNativeUtf8();
  final errPtr = calloc<Uint8>(512).cast<Utf8>();
  try {
    final rc = convert(inputPtr, outputPtr, errPtr, 512);
    final err = errPtr.toDartString();
    if (rc != 0) {
      throw Exception(err.isEmpty ? 'Native convert failed ($rc)' : err);
    }
  } finally {
    malloc.free(inputPtr);
    malloc.free(outputPtr);
    calloc.free(errPtr);
  }
}

int _filterWorker(Map<String, String> args) {
  return filterTrimbleDxf(args['input']!, args['output']!);
}

int _filterLayersWorker(Map<String, dynamic> args) {
  final layers = (args['layers'] as List).map((e) => '$e').toSet();
  return filterTrimbleDxfByLayers(
    args['input'] as String,
    args['output'] as String,
    layers,
  );
}

const stakeableTypes = {
  'LINE',
  'LWPOLYLINE',
  'POLYLINE',
  'ARC',
  'CIRCLE',
  'POINT',
  'INSERT',
  'VERTEX',
  'SEQEND',
};

/// Keep non-entity sections; in ENTITIES keep only Trimble-selectable types.
/// Does NOT explode Civil 3D proxies — Android uses Python recover_linework.
int filterTrimbleDxf(String inputPath, String outputPath) {
  return filterTrimbleDxfByLayers(inputPath, outputPath, null);
}

/// Like [filterTrimbleDxf], optionally keeping only entities on [keepLayers].
///
/// VERTEX / SEQEND follow the keep/drop decision of their parent POLYLINE.
int filterTrimbleDxfByLayers(
  String inputPath,
  String outputPath,
  Set<String>? keepLayers,
) {
  final lines = File(inputPath).readAsLinesSync();
  final out = StringBuffer();
  var inEntities = false;
  var stakeable = 0;
  String? code;

  // Buffer one entity so we can decide keep/drop after seeing its layer.
  final entityBuf = <String>[];
  String? entityType;
  String entityLayer = '0';
  // When inside a POLYLINE, VERTEX/SEQEND inherit the polyline keep flag.
  bool? polylineKeep;

  void flushEntity() {
    if (entityType == null) return;
    final typeOk = stakeableTypes.contains(entityType);
    late final bool keep;
    if (entityType == 'VERTEX' || entityType == 'SEQEND') {
      keep = typeOk && (polylineKeep ?? false);
      if (entityType == 'SEQEND') {
        polylineKeep = null;
      }
    } else {
      final layerOk =
          keepLayers == null || keepLayers.contains(entityLayer);
      keep = typeOk && layerOk;
      if (entityType == 'POLYLINE') {
        polylineKeep = keep;
      } else {
        polylineKeep = null;
      }
    }
    if (keep) {
      for (final line in entityBuf) {
        out.writeln(line);
      }
      if (entityType != 'VERTEX' && entityType != 'SEQEND') {
        stakeable += 1;
      }
    }
    entityBuf.clear();
    entityType = null;
    entityLayer = '0';
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimRight();
    final value = trimmed.trim();

    if (!inEntities) {
      out.writeln(trimmed);
      if (code == '2' && value == 'ENTITIES') {
        inEntities = true;
      }
      code = int.tryParse(value) != null ? value : null;
      continue;
    }

    if (code == '0') {
      if (value == 'ENDSEC') {
        flushEntity();
        polylineKeep = null;
        inEntities = false;
        out.writeln(trimmed);
        code = null;
        continue;
      }
      flushEntity();
      entityType = value;
      entityLayer = '0';
      entityBuf
        ..clear()
        ..add(trimmed);
      code = int.tryParse(value) != null ? value : null;
      continue;
    }

    if (entityType != null) {
      entityBuf.add(trimmed);
      if (code == '8') {
        entityLayer = value.isEmpty ? '0' : value;
      }
    }
    code = int.tryParse(value) != null ? value : null;
  }

  File(outputPath).writeAsStringSync(out.toString());
  return stakeable;
}
