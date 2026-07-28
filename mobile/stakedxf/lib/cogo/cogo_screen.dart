import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../points/csv_io.dart';
import '../points/dxf_linework.dart';
import '../points/plot_ui_theme.dart';
import '../points/survey_point.dart';
import 'cogo_linework.dart';
import 'cogo_math.dart';

enum _CogoMode { inverse, stationOffset }

/// Survey COGO on CSV points + imported DXF linework (station/offset).
class CogoScreen extends StatefulWidget {
  const CogoScreen({super.key});

  @override
  State<CogoScreen> createState() => _CogoScreenState();
}

class _CogoScreenState extends State<CogoScreen> {
  List<SurveyPoint> _points = const [];
  String? _pointsName;
  DxfLinework? _linework;
  String? _lineworkName;
  bool _busy = false;
  String? _status;
  String? _error;

  _CogoMode _mode = _CogoMode.inverse;
  String? _fromPt;
  String? _toPt;
  String? _staPt;
  String? _alignEntityId;
  double _beginStation = 0;

  InverseResult? _inverse;
  StationOffsetResult? _projection;

  Future<void> _pickPoints() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.single;
    try {
      final text = f.bytes != null
          ? utf8.decode(f.bytes!, allowMalformed: true)
          : await File(f.path!).readAsString();
      final pts = parsePointsCsv(text);
      if (pts.isEmpty) throw StateError('No points found in CSV.');
      setState(() {
        _points = pts;
        _pointsName = f.name;
        _fromPt = pts.first.id;
        _toPt = pts.length > 1 ? pts[1].id : pts.first.id;
        _staPt = pts.first.id;
        _inverse = null;
        _projection = null;
        _error = null;
        _status = '${pts.length} points · ${f.name}';
      });
    } catch (e) {
      setState(() => _error = 'Points: $e');
    }
  }

  Future<void> _pickDxf() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['dxf'],
      withData: false,
    );
    if (r == null || r.files.isEmpty || r.files.single.path == null) return;
    final path = r.files.single.path!;
    final name = r.files.single.name;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Parsing DXF…';
    });
    try {
      final lw = await compute(parseDxfLineworkFile, path);
      if (!mounted) return;
      final firstId = lw.entities.isEmpty ? null : lw.entities.first.id;
      setState(() {
        _linework = lw;
        _lineworkName = name;
        _alignEntityId = firstId;
        _projection = null;
        _busy = false;
        _status =
            '${lw.entities.length} entities · ${lw.layers.length} layers · $name';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'DXF: $e';
        _status = null;
      });
    }
  }

  SurveyPoint? _byId(String? id) {
    if (id == null) return null;
    for (final p in _points) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _runInverse() {
    final a = _byId(_fromPt);
    final b = _byId(_toPt);
    if (a == null || b == null) {
      setState(() => _error = 'Pick From and To points.');
      return;
    }
    setState(() {
      _error = null;
      _inverse = inverse(
        n1: a.northing,
        e1: a.easting,
        n2: b.northing,
        e2: b.easting,
      );
      _projection = null;
      _status = 'Inverse $_fromPt → $_toPt';
    });
  }

  void _runStationOffset() {
    final p = _byId(_staPt);
    final lw = _linework;
    if (p == null) {
      setState(() => _error = 'Pick a point.');
      return;
    }
    if (lw == null || lw.entities.isEmpty) {
      setState(() => _error = 'Import a DXF with linework first.');
      return;
    }
    var ents = lw.entities;
    if (_alignEntityId != null && _alignEntityId!.isNotEmpty) {
      ents = [
        for (final e in lw.entities)
          if (e.id == _alignEntityId) e,
      ];
      if (ents.isEmpty) ents = lw.entities;
    }
    final proj = projectPointToLinework(
      northing: p.northing,
      easting: p.easting,
      linework: ents,
      beginStation: _beginStation,
    );
    setState(() {
      _error = proj == null ? 'Could not project onto linework.' : null;
      _projection = proj;
      _inverse = null;
      _status = proj == null
          ? null
          : 'Sta ${formatStation(proj.station)}  '
              'Offset ${proj.offset.toStringAsFixed(3)}′';
    });
  }

  void _createFootPoint() {
    final proj = _projection;
    if (proj == null) return;
    final base = _byId(_staPt)?.id ?? 'PT';
    var name = '${base}_SO';
    final used = _points.map((p) => p.id).toSet();
    var i = 1;
    while (used.contains(name)) {
      name = '${base}_SO$i';
      i++;
    }
    setState(() {
      _points = [
        ..._points,
        SurveyPoint(
          id: name,
          northing: proj.projNorthing,
          easting: proj.projEasting,
          elevation: _byId(_staPt)?.elevation ?? 0,
          description: 'COGO foot',
        ),
      ];
      _status = 'Added point $name at perpendicular foot';
    });
  }

  Future<void> _exportPoints() async {
    if (_points.isEmpty) return;
    final csv = exportPointsCsv(_points);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/cogo_points_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'COGO points');
  }

  List<DropdownMenuItem<String>> _pointItems() => _points
      .map(
        (p) => DropdownMenuItem(
          value: p.id,
          child: Text(
            '${p.id}  (${p.northing.toStringAsFixed(2)}, '
            '${p.easting.toStringAsFixed(2)})',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
      .toList();

  List<DropdownMenuItem<String>> _entityItems(DxfLinework lw) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text('Nearest on all linework'),
      ),
    ];
    for (final e in lw.entities) {
      final len = lineworkEntityLength(e);
      items.add(
        DropdownMenuItem(
          value: e.id,
          child: Text(
            '${e.layer} · ${e.type} · ${len.toStringAsFixed(1)}′',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: PlotUi.bg,
      appBar: AppBar(
        title: const Text('COGO'),
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              tooltip: 'Share points CSV',
              onPressed: _busy ? null : _exportPoints,
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            'POINTS + LINEWORK',
            style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg),
          ),
          const SizedBox(height: 6),
          Text(
            'Inverse between CSV points, or project a point onto imported DXF '
            'linework for station & offset (right of travel = +).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickPoints,
                icon: const Icon(Icons.table_rows_rounded, size: 18),
                label: Text(
                  _points.isEmpty ? 'Import points CSV' : 'Replace points',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickDxf,
                icon: const Icon(Icons.polyline_rounded, size: 18),
                label: Text(_linework == null ? 'Import DXF' : 'Replace DXF'),
              ),
            ],
          ),
          if (_pointsName != null || _lineworkName != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (_pointsName != null)
                  'CSV: $_pointsName (${_points.length})',
                if (_lineworkName != null)
                  'DXF: $_lineworkName (${_linework?.entities.length ?? 0} ents)',
              ].join('\n'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error, height: 1.35)),
          ],
          if (_status != null && _error == null) ...[
            const SizedBox(height: 10),
            Text(
              _status!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          SegmentedButton<_CogoMode>(
            segments: const [
              ButtonSegment(
                value: _CogoMode.inverse,
                label: Text('Inverse'),
                icon: Icon(Icons.straighten_rounded, size: 18),
              ),
              ButtonSegment(
                value: _CogoMode.stationOffset,
                label: Text('Sta / Off'),
                icon: Icon(Icons.alt_route_rounded, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 18),
          if (_mode == _CogoMode.inverse) _buildInverse(context),
          if (_mode == _CogoMode.stationOffset) _buildStationOffset(context),
          if (_inverse != null) ...[
            const SizedBox(height: 18),
            _ResultCard(
              title: 'Inverse',
              rows: [
                ('Horizontal', '${_inverse!.distance.toStringAsFixed(3)} ft'),
                ('ΔN', _inverse!.deltaN.toStringAsFixed(3)),
                ('ΔE', _inverse!.deltaE.toStringAsFixed(3)),
                ('Azimuth', formatAzimuthDms(_inverse!.azimuthDeg)),
                ('Bearing', formatBearingDms(_inverse!.azimuthDeg)),
              ],
            ),
          ],
          if (_projection != null) ...[
            const SizedBox(height: 18),
            _ResultCard(
              title: 'Station / Offset',
              rows: [
                ('Station', formatStation(_projection!.station)),
                (
                  'Offset',
                  '${_projection!.offset >= 0 ? '+' : ''}'
                      '${_projection!.offset.toStringAsFixed(3)} ft'
                ),
                (
                  'Perp. dist',
                  '${_projection!.distance.toStringAsFixed(3)} ft'
                ),
                ('Layer', _projection!.layer),
                ('Type', _projection!.entityType),
                ('Foot N', _projection!.projNorthing.toStringAsFixed(4)),
                ('Foot E', _projection!.projEasting.toStringAsFixed(4)),
              ],
              trailing: TextButton.icon(
                onPressed: _createFootPoint,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add foot as point'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInverse(BuildContext context) {
    if (_points.isEmpty) {
      return Text(
        'Import a points CSV to run Inverse.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _fromPt,
          decoration: const InputDecoration(
            labelText: 'From',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _pointItems(),
          onChanged: (v) => setState(() => _fromPt = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _toPt,
          decoration: const InputDecoration(
            labelText: 'To',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _pointItems(),
          onChanged: (v) => setState(() => _toPt = v),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _runInverse,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calculate inverse'),
        ),
      ],
    );
  }

  Widget _buildStationOffset(BuildContext context) {
    final lw = _linework;
    if (_points.isEmpty) {
      return Text(
        'Import points CSV and a DXF (same workflow as Plot).',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _staPt,
          decoration: const InputDecoration(
            labelText: 'Point',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _pointItems(),
          onChanged: (v) => setState(() => _staPt = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _beginStation == 0 ? '' : _beginStation.toString(),
          decoration: const InputDecoration(
            labelText: 'Begin station (ft)',
            hintText: '0',
            border: OutlineInputBorder(),
            isDense: true,
            helperText: 'Station at start of alignment = this value',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          onChanged: (v) {
            final n = double.tryParse(v.trim());
            if (n != null) _beginStation = n;
          },
        ),
        const SizedBox(height: 12),
        if (lw != null && lw.entities.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _alignEntityId ?? '',
            decoration: const InputDecoration(
              labelText: 'Alignment / linework',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _entityItems(lw),
            onChanged: (v) => setState(() {
              _alignEntityId = (v == null || v.isEmpty) ? null : v;
            }),
          )
        else
          Text(
            'Import a DXF to project onto centerline / curb / ROW linework.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _runStationOffset,
          icon: const Icon(Icons.alt_route_rounded),
          label: const Text('Station & offset'),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.rows,
    this.trailing,
  });

  final String title;
  final List<(String, String)> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: PlotUi.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PlotUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg),
          ),
          const SizedBox(height: 10),
          for (final r in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    r.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    r.$2,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: trailing!),
          ],
        ],
      ),
    );
  }
}
