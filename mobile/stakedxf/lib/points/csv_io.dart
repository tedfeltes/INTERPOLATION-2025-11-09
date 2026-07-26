import 'survey_point.dart';

/// Parse Trimble / Civil 3D style point CSVs.
///
/// Supported:
/// - PNEZD: Point, Northing, Easting, Elevation, Description
/// - PENZD: Point, Easting, Northing, Elevation, Description
/// - Headered CSV with those column names (any order)
/// - Whitespace/comma delimited without headers (assumes PNEZD)
List<SurveyPoint> parsePointsCsv(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  if (lines.isEmpty) return const [];

  final firstCells = _splitRow(lines.first);
  final headerMap = _headerIndex(firstCells);
  final start = headerMap == null ? 0 : 1;
  final points = <SurveyPoint>[];

  for (var i = start; i < lines.length; i++) {
    final cells = _splitRow(lines[i]);
    if (cells.length < 4) continue;
    try {
      final pt = headerMap == null
          ? _fromPnezd(cells)
          : _fromHeadered(cells, headerMap);
      if (pt != null) points.add(pt);
    } catch (_) {
      // skip bad rows
    }
  }

  points.sort(_pointSort);
  return points;
}

String exportPointsCsv(List<SurveyPoint> points, {bool header = true}) {
  final buf = StringBuffer();
  if (header) {
    buf.writeln('Point,Northing,Easting,Elevation,Description');
  }
  for (final p in points) {
    final desc = _csvEscape(p.description);
    buf.writeln(
      '${p.id},${p.northingText},${p.eastingText},${p.elevText},$desc',
    );
  }
  return buf.toString();
}

List<String> _splitRow(String line) {
  if (line.contains(',')) {
    return _parseCsvLine(line);
  }
  return line.split(RegExp(r'\s+')).where((c) => c.isNotEmpty).toList();
}

List<String> _parseCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      out.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString().trim());
  return out;
}

Map<String, int>? _headerIndex(List<String> cells) {
  final lower = cells.map((c) => c.toLowerCase().replaceAll(' ', '')).toList();
  final hasPoint = lower.any(
    (c) => c == 'point' || c == 'point#' || c == 'pointno' || c == 'name' || c == 'id',
  );
  final hasN = lower.any((c) => c == 'northing' || c == 'n' || c == 'y');
  final hasE = lower.any((c) => c == 'easting' || c == 'e' || c == 'x');
  if (!hasPoint || !hasN || !hasE) return null;

  int idx(List<String> names) {
    for (final name in names) {
      final i = lower.indexOf(name);
      if (i >= 0) return i;
    }
    return -1;
  }

  return {
    'id': idx(['point', 'point#', 'pointno', 'name', 'id']),
    'n': idx(['northing', 'n', 'y']),
    'e': idx(['easting', 'e', 'x']),
    'z': idx(['elevation', 'elev', 'z', 'height']),
    'd': idx(['description', 'desc', 'code', 'feature']),
  };
}

SurveyPoint? _fromPnezd(List<String> cells) {
  if (cells.length < 5) {
    // Point,N,E,Z only
    if (cells.length < 4) return null;
    return SurveyPoint(
      id: cells[0],
      northing: double.parse(cells[1]),
      easting: double.parse(cells[2]),
      elevation: double.parse(cells[3]),
      description: '',
    );
  }
  return SurveyPoint(
    id: cells[0],
    northing: double.parse(cells[1]),
    easting: double.parse(cells[2]),
    elevation: double.parse(cells[3]),
    description: cells.sublist(4).join(' ').trim(),
  );
}

SurveyPoint? _fromHeadered(List<String> cells, Map<String, int> map) {
  String at(String key, [String fallback = '']) {
    final i = map[key] ?? -1;
    if (i < 0 || i >= cells.length) return fallback;
    return cells[i];
  }

  final id = at('id');
  final n = at('n');
  final e = at('e');
  if (id.isEmpty || n.isEmpty || e.isEmpty) return null;
  final z = at('z', '0');
  return SurveyPoint(
    id: id,
    northing: double.parse(n),
    easting: double.parse(e),
    elevation: double.parse(z.isEmpty ? '0' : z),
    description: at('d'),
  );
}

int _pointSort(SurveyPoint a, SurveyPoint b) {
  final ai = int.tryParse(a.id);
  final bi = int.tryParse(b.id);
  if (ai != null && bi != null) return ai.compareTo(bi);
  if (ai != null) return -1;
  if (bi != null) return 1;
  return a.id.compareTo(b.id);
}

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
