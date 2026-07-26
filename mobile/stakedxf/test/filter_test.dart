import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/converter.dart';

void main() {
  test('filter keeps stakeable entities', () {
    final dir = Directory.systemTemp.createTempSync('stakedxf');
    final input = File('${dir.path}/in.dxf');
    input.writeAsStringSync('''
0
SECTION
2
HEADER
0
ENDSEC
0
SECTION
2
ENTITIES
0
LINE
8
CL
0
TEXT
8
NOTES
0
ARC
8
CURB
0
ENDSEC
0
EOF
''');
    final output = '${dir.path}/out.dxf';
    final count = filterTrimbleDxf(input.path, output);
    final text = File(output).readAsStringSync();
    expect(count, 2);
    expect(text.contains('LINE'), isTrue);
    expect(text.contains('ARC'), isTrue);
    expect(text.contains('TEXT'), isFalse);
    dir.deleteSync(recursive: true);
  });
}
