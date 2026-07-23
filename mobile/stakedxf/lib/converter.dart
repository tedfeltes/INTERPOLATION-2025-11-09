import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
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
  });

  final String outputPath;
  final int stakeableCount;
  final String message;
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
  /// Convert DWG/DXF → Trimble-filtered DXF on a background isolate.
  Future<ConvertResult> convertFile({
    required String inputPath,
    required String outputPath,
  }) {
    return compute(_convertWorker, <String, String>{
      'input': inputPath,
      'output': outputPath,
    });
  }
}

ConvertResult _convertWorker(Map<String, String> args) {
  final input = args['input']!;
  final output = args['output']!;
  final lower = input.toLowerCase();

  var rawDxf = output;
  if (lower.endsWith('.dwg')) {
    rawDxf = '$output.raw.dxf';
    final lib = _openLib();
    final convert = lib.lookupFunction<_ConvertNative, _ConvertDart>(
      'stakedxf_convert',
    );
    final inputPtr = input.toNativeUtf8();
    final outputPtr = rawDxf.toNativeUtf8();
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
  } else if (lower.endsWith('.dxf')) {
    rawDxf = input;
  } else {
    throw Exception('Choose a .dwg or .dxf file');
  }

  final stakeable = filterTrimbleDxf(rawDxf, output);
  if (rawDxf != input && rawDxf != output) {
    try {
      File(rawDxf).deleteSync();
    } catch (_) {}
  }

  return ConvertResult(
    outputPath: output,
    stakeableCount: stakeable,
    message: stakeable > 0
        ? 'Ready for Trimble Access stakeout'
        : 'No stakeable linework found in this drawing.',
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
      if (keep &&
          value != 'VERTEX' &&
          value != 'SEQEND') {
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
