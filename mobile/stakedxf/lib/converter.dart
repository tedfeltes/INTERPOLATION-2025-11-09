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

class ConvertResult {
  ConvertResult({
    required this.outputPath,
    required this.stakeableCount,
    required this.message,
    this.proxyExploded = 0,
  });

  final String outputPath;
  final int stakeableCount;
  final String message;
  final int proxyExploded;
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

class NativeConverter {
  static const _linework = MethodChannel('com.stakedxf/linework');

  /// Convert DWG/DXF → Trimble stakeable DXF.
  ///
  /// On Android: DWG→DXF via LibreDWG, then Python recovers Civil 3D proxy
  /// linework (ACAD_PROXY_ENTITY) into LINE/ARC/POLYLINE before filtering.
  Future<ConvertResult> convertFile({
    required String inputPath,
    required String outputPath,
  }) async {
    final lower = inputPath.toLowerCase();
    var rawDxf = outputPath;

    if (lower.endsWith('.dwg')) {
      rawDxf = '$outputPath.raw.dxf';
      await compute(_dwgToDxfWorker, <String, String>{
        'input': inputPath,
        'output': rawDxf,
      });
    } else if (lower.endsWith('.dxf')) {
      rawDxf = inputPath;
    } else {
      throw Exception('Choose a .dwg or .dxf file');
    }

    try {
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
        final message = recovered['message']?.toString() ??
            (stakeable > 0
                ? 'Recovered $stakeable stakeable entities'
                : 'No stakeable linework found in this drawing.');
        return ConvertResult(
          outputPath: outputPath,
          stakeableCount: stakeable,
          proxyExploded: proxyExploded,
          message: message,
        );
      }

      // Host / iOS fallback: text filter only (no proxy explode).
      final stakeable = await compute(_filterWorker, <String, String>{
        'input': rawDxf,
        'output': outputPath,
      });
      return ConvertResult(
        outputPath: outputPath,
        stakeableCount: stakeable,
        message: stakeable > 0
            ? 'Ready for Trimble Access stakeout'
            : 'No stakeable linework found in this drawing.',
      );
    } finally {
      if (rawDxf != inputPath && rawDxf != outputPath) {
        try {
          File(rawDxf).deleteSync();
        } catch (_) {}
      }
    }
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
  final lines = File(inputPath).readAsLinesSync();
  final out = StringBuffer();
  var inEntities = false;
  var keep = true;
  var stakeable = 0;
  String? code;

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

    // ENTITIES section
    if (code == '0') {
      if (value == 'ENDSEC') {
        keep = true;
        inEntities = false;
        out.writeln(trimmed);
        code = null;
        continue;
      }
      keep = stakeableTypes.contains(value);
      if (keep && value != 'VERTEX' && value != 'SEQEND') {
        stakeable += 1;
      }
    }

    if (keep) {
      out.writeln(trimmed);
    }
    code = int.tryParse(value) != null ? value : null;
  }

  File(outputPath).writeAsStringSync(out.toString());
  return stakeable;
}
