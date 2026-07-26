import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'block_catalog.dart';
import 'block_catalog_asset.dart';
import 'csv_io.dart';
import 'dxf_linework.dart';
import 'label_placement.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_preview.dart';
import 'plot_symbols.dart';
import 'plot_templates.dart';
import 'survey_point.dart';
import 'symbol_library_sheet.dart';
import 'symbol_preview.dart';

/// Export Points screen — import CSV, customize plot, export CSV / staking plot PDF.
class ExportPointsScreen extends StatefulWidget {
  const ExportPointsScreen({super.key});

  @override
  State<ExportPointsScreen> createState() => _ExportPointsScreenState();
}

class _ExportPointsScreenState extends State<ExportPointsScreen> {
  final _jobCtrl = TextEditingController();
  List<SurveyPoint> _points = const [];
  final Set<String> _selected = {};
  String? _sourceName;
  String? _dxfName;
  DxfLinework? _linework;
  final Set<String> _selectedLayers = {};
  PlotOptions _options = const PlotOptions();
  final List<PlacedPlotSymbol> _symbols = [];
  String? _selectedSymbolId;
  String? _selectedLabelPointId;
  BlockCatalog? _blockCatalog;
  String? _error;
  String? _status;
  bool _busy = false;
  bool _plotOptionsOpen = true;
  bool _lineworkOpen = false;
  bool _objectsOpen = false;
  bool _pointsOpen = false;

  @override
  void initState() {
    super.initState();
    BlockCatalogAsset.loadCached().then((c) {
      if (!mounted) return;
      setState(() => _blockCatalog = c);
    });
  }

  @override
  void dispose() {
    _jobCtrl.dispose();
    super.dispose();
  }

  List<SurveyPoint> get _chosen =>
      _points.where((pt) => _selected.contains(pt.id)).toList();

  List<LineworkEntity> get _chosenLinework {
    final lw = _linework;
    if (lw == null || !_options.includeLinework) return const [];
    final pts = _chosen.isNotEmpty ? _chosen : _points;
    if (pts.isEmpty) return lw.forLayersCapped(_selectedLayers);
    return lw.forLayersNear(
      _selectedLayers,
      points: [
        for (final p in pts) (easting: p.easting, northing: p.northing),
      ],
    );
  }

  PlacedPlotSymbol? get _selectedSymbol {
    final id = _selectedSymbolId;
    if (id == null) return null;
    for (final s in _symbols) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _moveSymbol(String id, double easting, double northing) {
    final i = _symbols.indexWhere((s) => s.id == id);
    if (i < 0) return;
    setState(() {
      _symbols[i] = _symbols[i].copyWith(easting: easting, northing: northing);
      _selectedSymbolId = id;
      _selectedLabelPointId = null;
    });
  }

  /// Civil 3D–style label drag: offset only — point marker stays fixed.
  void _moveLabel(String pointId, double offsetE, double offsetN) {
    final next = Map<String, LabelDragState>.from(_options.labelDrags);
    final prev = next[pointId];
    next[pointId] = LabelDragState(
      offsetE: offsetE,
      offsetN: offsetN,
      customText: prev?.customText,
    );
    setState(() {
      _options = _options.copyWith(labelDrags: next);
      _selectedLabelPointId = pointId;
      _selectedSymbolId = null;
    });
  }

  void _setLabelCustomText(String pointId, String? text) {
    final next = Map<String, LabelDragState>.from(_options.labelDrags);
    final prev = next[pointId] ?? const LabelDragState(offsetE: 14, offsetN: 10);
    final trimmed = text?.trim();
    next[pointId] = prev.copyWith(
      customText: trimmed,
      clearCustomText: trimmed == null || trimmed.isEmpty,
    );
    setState(() => _options = _options.copyWith(labelDrags: next));
  }

  void _resetLabelDrags() {
    setState(() {
      _options = _options.copyWith(labelDrags: const {});
      _selectedLabelPointId = null;
      _status = 'Label positions reset — auto-spread will re-pack on export';
    });
  }

  void _updateSelectedSymbol({
    double? scale,
    double? rotationDeg,
    int? colorArgb,
  }) {
    final id = _selectedSymbolId;
    if (id == null) return;
    final i = _symbols.indexWhere((s) => s.id == id);
    if (i < 0) return;
    setState(() {
      _symbols[i] = _symbols[i].copyWith(
        scale: scale,
        rotationDeg: rotationDeg,
        colorArgb: colorArgb,
      );
    });
  }

  SurveyPoint? get _selectedLabelPoint {
    final id = _selectedLabelPointId;
    if (id == null) return null;
    for (final p in _points) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _importCsv() async {
    setState(() {
      _error = null;
      _status = null;
    });
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final lower = file.name.toLowerCase();
    if (!(lower.endsWith('.csv') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.asc'))) {
      setState(() => _error = 'Pick a points CSV / TXT export (PNEZD).');
      return;
    }

    String? text =
        file.bytes != null ? utf8.decode(file.bytes!, allowMalformed: true) : null;
    if ((text == null || text.trim().isEmpty) && file.path != null) {
      text = await File(file.path!).readAsString();
    }
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = 'Could not read that file.');
      return;
    }

    final parsed = parsePointsCsv(text);
    if (parsed.isEmpty) {
      setState(
        () => _error =
            'No points found. Use Point, Northing, Easting, Elevation, Description.',
      );
      return;
    }

    setState(() {
      _points = parsed;
      _selected
        ..clear()
        ..addAll(parsed.map((pt) => pt.id));
      _sourceName = file.name;
      _status = 'Loaded ${parsed.length} points';
      if (_jobCtrl.text.trim().isEmpty) {
        _jobCtrl.text = p.basenameWithoutExtension(file.name).toUpperCase();
      }
    });
  }

  Future<void> _linkDxf() async {
    setState(() {
      _error = null;
      _status = null;
    });
    // IMPORTANT: withData must stay false. Shipping a large converted DXF
    // through the platform channel exceeds Android's ~1 MB binder limit and
    // crashes the app. Read from the file path in a background isolate.
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final lower = file.name.toLowerCase();
    if (!lower.endsWith('.dxf')) {
      setState(() => _error = 'Pick a .dxf file to link as plot linework.');
      return;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      setState(
        () => _error =
            'Could not access that DXF path. Copy it into device storage '
            'and pick it again.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Reading DXF linework…';
    });
    try {
      final sizeMb = File(path).lengthSync() / (1024 * 1024);
      final parsed = await compute(parseDxfLineworkFile, path);
      if (parsed.entities.isEmpty) {
        setState(
          () => _error =
              'No LINE / LWPOLYLINE / ARC / CIRCLE linework found in that DXF.',
        );
        return;
      }

      final capped = parsed.entities.length > kMaxPlotLineworkEntities;
      setState(() {
        _linework = parsed;
        _dxfName = file.name;
        _selectedLayers
          ..clear()
          ..addAll(parsed.layers);
        _options = _options.copyWith(includeLinework: true);
        _status =
            'Linked ${parsed.entities.length} entities on ${parsed.layers.length} layers'
            '${sizeMb >= 1 ? ' (${sizeMb.toStringAsFixed(1)} MB)' : ''}'
            '${capped ? ' — plot will draw first $kMaxPlotLineworkEntities for stability' : ''}';
      });
    } catch (e) {
      setState(() => _error = 'Could not link DXF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearDxf() {
    setState(() {
      _linework = null;
      _dxfName = null;
      _selectedLayers.clear();
      _status = 'Cleared linked DXF linework';
    });
  }

  void _selectAll(bool value) {
    setState(() {
      _selected
        ..clear()
        ..addAll(value ? _points.map((pt) => pt.id) : const <String>[]);
    });
  }

  void _selectAllLayers(bool value) {
    final lw = _linework;
    if (lw == null) return;
    setState(() {
      _selectedLayers
        ..clear()
        ..addAll(value ? lw.layers : const <String>[]);
    });
  }

  Future<void> _addSymbol() async {
    final placed = await showSymbolLibrarySheet(
      context: context,
      anchorPoints: _chosen.isNotEmpty ? _chosen : _points,
      blockCatalog: _blockCatalog,
    );
    if (placed == null) return;
    setState(() {
      _symbols.add(placed);
      _selectedSymbolId = placed.id;
      _status =
          'Added ${placed.libraryLabel} — drag it on the preview to position';
    });
  }

  Future<void> _editSymbol(int index) async {
    if (index < 0 || index >= _symbols.length) return;
    final placed = await showSymbolLibrarySheet(
      context: context,
      anchorPoints: _chosen.isNotEmpty ? _chosen : _points,
      existing: _symbols[index],
      blockCatalog: _blockCatalog,
    );
    if (placed == null) return;
    setState(() {
      _symbols[index] = placed;
      _selectedSymbolId = placed.id;
      _status = 'Updated ${placed.libraryLabel}';
    });
  }

  void _removeSymbol(int index) {
    if (index < 0 || index >= _symbols.length) return;
    final removed = _symbols.removeAt(index);
    setState(() {
      if (_selectedSymbolId == removed.id) _selectedSymbolId = null;
      _status = 'Removed ${removed.libraryLabel}';
    });
  }

  Future<void> _exportCsv() async {
    final chosen = _chosen;
    if (chosen.isEmpty) {
      setState(() => _error = 'Select at least one point to export.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final csv = exportPointsCsv(chosen);
      final docs = await getApplicationDocumentsDirectory();
      final stem = _jobCtrl.text.trim().isEmpty
          ? 'points'
          : _jobCtrl.text.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
      final out = File(p.join(docs.path, '${stem}_export.csv'));
      await out.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(out.path, mimeType: 'text/csv')],
        text: 'Exported stake points',
      );
      setState(() => _status = 'Exported ${chosen.length} points to CSV');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _exportPlot() async {
    final chosen = _chosen;
    if (chosen.isEmpty) {
      setState(() => _error = 'Select at least one point for the staking plot.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final linework = _chosenLinework;
      final symbols = List<PlacedPlotSymbol>.from(_symbols);
      final bytes = await buildStakingPlotPdf(
        points: chosen,
        jobName: _jobCtrl.text.trim(),
        options: _options,
        linework: linework,
        symbols: symbols,
        blockCatalog: _blockCatalog,
      );
      final scale = chooseEngineeringScale(
        chosen,
        linework: linework,
        symbols: symbols,
        template: _options.template,
        showPointList: _options.showPointList,
      ).round();
      final docs = await getApplicationDocumentsDirectory();
      final stem = _jobCtrl.text.trim().isEmpty
          ? 'staking_plot'
          : _jobCtrl.text.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
      final out = File(p.join(docs.path, '${stem}_staking_plot.pdf'));
      await out.writeAsBytes(bytes, flush: true);
      final tpl = _options.template;
      await Share.shareXFiles(
        [XFile(out.path, mimeType: 'application/pdf')],
        text: 'Staking plot ${tpl.sizeCallout} 1"=$scale\'',
      );
      final lwNote = linework.isEmpty ? '' : ', ${linework.length} linework';
      final symNote =
          symbols.isEmpty ? '' : ', ${symbols.length} library object(s)';
      setState(
        () => _status =
            'Staking plot ready — ${tpl.name}, ${chosen.length} points$lwNote$symNote @ 1"=$scale\'',
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allSelected =
        _points.isNotEmpty && _selected.length == _points.length;
    final lw = _linework;
    final allLayers =
        lw != null &&
        lw.layers.isNotEmpty &&
        _selectedLayers.length == lw.layers.length;

    final previewPoints = _chosen.isNotEmpty ? _chosen : _points;
    final selectedSym = _selectedSymbol;
    final selectedLabel = _selectedLabelPoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Points'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (previewPoints.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlotPreview(
                      points: previewPoints,
                      options: _options,
                      linework: _chosenLinework,
                      symbols: _symbols,
                      blockCatalog: _blockCatalog,
                      selectedSymbolId: _selectedSymbolId,
                      selectedLabelPointId: _selectedLabelPointId,
                      onSelectSymbol: (id) => setState(() {
                        _selectedSymbolId = id;
                        if (id != null) _selectedLabelPointId = null;
                      }),
                      onSelectLabelPoint: (id) => setState(() {
                        _selectedLabelPointId = id;
                        if (id != null) _selectedSymbolId = null;
                      }),
                      onMoveSymbol: _moveSymbol,
                      onMoveLabel: _moveLabel,
                      height: 240,
                    ),
                    if (selectedLabel != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B281C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x59E4572E)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Label · point ${selectedLabel.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final next =
                                        Map<String, LabelDragState>.from(
                                      _options.labelDrags,
                                    )..remove(selectedLabel.id);
                                    setState(() {
                                      _options =
                                          _options.copyWith(labelDrags: next);
                                      _selectedLabelPointId = null;
                                    });
                                  },
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                            Text(
                              'Point marker stays fixed. Drag the label on the '
                              'preview (Civil 3D drag state). Edit text below '
                              'to customize this callout.',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: ValueKey(
                                'label-text-${selectedLabel.id}-'
                                '${_options.labelFormat.name}',
                              ),
                              initialValue: _options
                                      .labelDrags[selectedLabel.id]
                                      ?.customText ??
                                  labelLinesFor(
                                    selectedLabel,
                                    _options.labelFormat,
                                  ).join('\n'),
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Label text',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  _setLabelCustomText(selectedLabel.id, v),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (selectedSym != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B281C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x59E4572E)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedSym.libraryLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final i = _symbols
                                        .indexWhere((s) => s.id == selectedSym.id);
                                    if (i >= 0) _editSymbol(i);
                                  },
                                  child: const Text('Edit'),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () {
                                    final i = _symbols
                                        .indexWhere((s) => s.id == selectedSym.id);
                                    if (i >= 0) _removeSymbol(i);
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 28,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final c in PlotSymbolColor.presets)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: GestureDetector(
                                        onTap: () => _updateSelectedSymbol(
                                          colorArgb: c.argb,
                                        ),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Color(c.argb),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: selectedSym.colorArgb ==
                                                      c.argb
                                                  ? Colors.white
                                                  : Colors.white24,
                                              width: selectedSym.colorArgb ==
                                                      c.argb
                                                  ? 2
                                                  : 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Text('Scale', style: TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Slider(
                                    value: selectedSym.scale.clamp(0.25, 5.0),
                                    min: 0.25,
                                    max: 5.0,
                                    divisions: 19,
                                    onChanged: (v) =>
                                        _updateSelectedSymbol(scale: v),
                                  ),
                                ),
                                Text(
                                  '${selectedSym.scale.toStringAsFixed(2)}×',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(
                    'Import points, link DXF linework, place objects on the '
                    'live preview, then export the staking plot PDF.',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _jobCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Job name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _importCsv,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _sourceName == null
                          ? 'Import points CSV / TXT'
                          : 'Reload: $_sourceName',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _linkDxf,
                    icon: const Icon(Icons.polyline),
                    label: Text(
                      _dxfName == null
                          ? 'Link DXF linework (optional)'
                          : 'Reload DXF: $_dxfName',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_dxfName != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _clearDxf,
                        child: const Text('Clear DXF'),
                      ),
                    ),
                  if (_points.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CollapsibleSection(
                      title: 'Plot options',
                      expanded: _plotOptionsOpen,
                      onExpansionChanged: (v) =>
                          setState(() => _plotOptionsOpen = v),
                      children: [
                        DropdownButtonFormField<PlotTemplate>(
                          value: plotTemplateById(_options.template.id),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Plot template (ANSI sheet)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final t in kPlotTemplates)
                              DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(
                                    () => _options =
                                        _options.copyWith(template: v),
                                  );
                                },
                        ),
                        if (_options.template.blurb.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_options.template.subtitle}\n${_options.template.blurb}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        DropdownButtonFormField<PointMarkerStyle>(
                          value: _options.markerStyle,
                          decoration: const InputDecoration(
                            labelText: 'Point marker',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final m in PointMarkerStyle.values)
                              DropdownMenuItem(
                                value: m,
                                child: Text(m.label),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(
                                    () => _options =
                                        _options.copyWith(markerStyle: v),
                                  );
                                },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<PointLabelFormat>(
                          value: _options.labelFormat,
                          decoration: const InputDecoration(
                            labelText: 'Point label',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final f in PointLabelFormat.values)
                              DropdownMenuItem(
                                value: f,
                                child: Text(f.label),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(
                                    () => _options =
                                        _options.copyWith(labelFormat: v),
                                  );
                                },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Annotation scale',
                              style: TextStyle(fontSize: 13),
                            ),
                            Expanded(
                              child: Slider(
                                value:
                                    _options.annotationScale.clamp(0.6, 3.0),
                                min: 0.6,
                                max: 3.0,
                                divisions: 24,
                                label: _options.annotationScale
                                    .toStringAsFixed(1),
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(
                                          () => _options = _options.copyWith(
                                            annotationScale: v,
                                          ),
                                        ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${_options.annotationScale.toStringAsFixed(1)}×',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Keeps labels, markers, and library objects readable '
                          'when points are hundreds or thousands of feet apart.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-spread stacked labels'),
                          subtitle: const Text(
                            'Pack undragged labels like Civil 3D drag state. '
                            'Drag any label on the preview to pin it.',
                          ),
                          value: _options.autoSpreadLabels,
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                    () => _options = _options.copyWith(
                                      autoSpreadLabels: v,
                                    ),
                                  ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _busy || _options.labelDrags.isEmpty
                                ? null
                                : _resetLabelDrags,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(
                              'Reset dragged labels'
                              '${_options.labelDrags.isEmpty ? '' : ' (${_options.labelDrags.length})'}',
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Include point list table'),
                          subtitle: Text(
                            _options.template.layout ==
                                    PlotTemplateLayout.sidePanel
                                ? 'Control-note templates only — off by default for more plot space'
                                : 'Applies to Control note templates (ignored on field-map sheets)',
                          ),
                          value: _options.showPointList,
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                    () => _options =
                                        _options.copyWith(showPointList: v),
                                  ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show library object names'),
                          subtitle: const Text(
                            'Off by default — objects draw without text labels',
                          ),
                          value: _options.showObjectLabels,
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                    () => _options = _options.copyWith(
                                      showObjectLabels: v,
                                    ),
                                  ),
                        ),
                        Row(
                          children: [
                            const Text(
                              'Object paper size',
                              style: TextStyle(fontSize: 13),
                            ),
                            Expanded(
                              child: Slider(
                                value: _options.symbolPaperInches
                                    .clamp(0.12, 0.8),
                                min: 0.12,
                                max: 0.8,
                                divisions: 17,
                                label:
                                    '${_options.symbolPaperInches.toStringAsFixed(2)}"',
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(
                                          () => _options = _options.copyWith(
                                            symbolPaperInches: v,
                                          ),
                                        ),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${_options.symbolPaperInches.toStringAsFixed(2)}"',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (lw != null)
                      _CollapsibleSection(
                        title:
                            'DXF linework (${_selectedLayers.length}/${lw.layers.length})',
                        expanded: _lineworkOpen,
                        onExpansionChanged: (v) =>
                            setState(() => _lineworkOpen = v),
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Draw linked DXF linework'),
                            value: _options.includeLinework,
                            onChanged: _busy
                                ? null
                                : (v) => setState(
                                      () => _options = _options.copyWith(
                                        includeLinework: v,
                                      ),
                                    ),
                          ),
                          if (_options.includeLinework) ...[
                            Row(
                              children: [
                                const Text(
                                  'Layers',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () =>
                                      _selectAllLayers(!allLayers),
                                  child: Text(allLayers ? 'Clear' : 'All'),
                                ),
                              ],
                            ),
                            ...lw.layers.map((layer) {
                              final count = lw.countForLayer(layer);
                              return CheckboxListTile(
                                value: _selectedLayers.contains(layer),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(layer),
                                subtitle: Text(
                                  '$count entit${count == 1 ? "y" : "ies"}',
                                ),
                                onChanged: _busy
                                    ? null
                                    : (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedLayers.add(layer);
                                          } else {
                                            _selectedLayers.remove(layer);
                                          }
                                        });
                                      },
                              );
                            }),
                          ],
                        ],
                      ),
                    _CollapsibleSection(
                      title: 'Plot objects (${_symbols.length})',
                      expanded: _objectsOpen,
                      onExpansionChanged: (v) =>
                          setState(() => _objectsOpen = v),
                      trailing: _symbols.isEmpty
                          ? null
                          : TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _symbols.clear();
                                        _selectedSymbolId = null;
                                      }),
                              child: const Text('Clear'),
                            ),
                      children: [
                        Text(
                          'Add objects from the library. Drag on the live '
                          'preview to place. Scale uses paper size × object '
                          'scale × annotation scale (point markers stay fixed).'
                          '${_blockCatalog == null ? '' : '  ${_blockCatalog!.blocks.length} DWG blocks loaded.'}',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.65),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _addSymbol,
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Add from object library'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                        ..._symbols.asMap().entries.map((entry) {
                          final i = entry.key;
                          final sym = entry.value;
                          final caption = sym.libraryLabel;
                          final selected = sym.id == _selectedSymbolId;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            selected: selected,
                            onTap: () => setState(() {
                              _selectedSymbolId = sym.id;
                              _selectedLabelPointId = null;
                            }),
                            leading: SizedBox(
                              width: 36,
                              height: 36,
                              child: CustomPaint(
                                painter: sym.kind != null
                                    ? SymbolPreviewPainter(
                                        sym.kind!,
                                        color: Color(sym.colorArgb),
                                      )
                                    : (_blockCatalog != null &&
                                            sym.blockId != null &&
                                            _blockCatalog![sym.blockId!] !=
                                                null)
                                        ? BlockPreviewPainter(
                                            _blockCatalog![sym.blockId!]!,
                                            color: Color(sym.colorArgb),
                                          )
                                        : SymbolPreviewPainter(
                                            PlotSymbolKind.hub,
                                            color: Color(sym.colorArgb),
                                          ),
                              ),
                            ),
                            title: Text(
                              caption,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'N ${sym.northing.toStringAsFixed(2)}  '
                              'E ${sym.easting.toStringAsFixed(2)}  ·  '
                              '${sym.scale.toStringAsFixed(2)}×  ·  '
                              '${sym.rotationDeg.toStringAsFixed(0)}°',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed:
                                      _busy ? null : () => _editSymbol(i),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed:
                                      _busy ? null : () => _removeSymbol(i),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    _CollapsibleSection(
                      title:
                          'Points (${_selected.length}/${_points.length})',
                      expanded: _pointsOpen,
                      onExpansionChanged: (v) =>
                          setState(() => _pointsOpen = v),
                      trailing: TextButton(
                        onPressed: () => _selectAll(!allSelected),
                        child: Text(allSelected ? 'Clear' : 'Select all'),
                      ),
                      children: [
                        ..._points.map((pt) {
                          final checked = _selected.contains(pt.id);
                          return CheckboxListTile(
                            value: checked,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              '${pt.id}  ${pt.description}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'N ${pt.northingText}   E ${pt.eastingText}   Z ${pt.elevText}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                            onChanged: _busy
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selected.add(pt.id);
                                      } else {
                                        _selected.remove(pt.id);
                                      }
                                    });
                                  },
                          );
                        }),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _status!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed:
                        _busy || _selected.isEmpty ? null : _exportPlot,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('Create staking plot PDF'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _busy || _selected.isEmpty ? null : _exportCsv,
                    icon: const Icon(Icons.table_rows),
                    label: const Text('Export selected points CSV'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact collapsible menu used throughout Export Points.
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.expanded,
    required this.onExpansionChanged,
    required this.children,
    this.trailing,
  });

  final String title;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      elevation: 0,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        maintainState: true,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: cs.primary,
          ),
        ),
        trailing: trailing == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  trailing!,
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
        children: children,
      ),
    );
  }
}
