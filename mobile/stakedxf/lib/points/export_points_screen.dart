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
import 'ctb_plot_style.dart';
import 'label_placement.dart';
import 'layer_properties_manager.dart';
import 'linetype_catalog.dart';
import 'linework_edit.dart';
import 'linework_style.dart';
import 'plot_annotations.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_preview.dart';
import 'point_properties_panel.dart';
import 'plot_symbols.dart';
import 'plot_templates.dart';
import 'sticky_section.dart';
import 'survey_point.dart';
import 'symbol_library_sheet.dart';
import 'symbol_preview.dart';
import 'color_picker_sheet.dart';
import 'plot_ui_theme.dart';
import 'text_style_catalog.dart';
import 'text_style_picker_sheet.dart';

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
  String? _selectedLineworkId;
  String? _selectedLineworkLayer;
  int? _selectedNodeIndex;
  int? _selectedSegmentIndex;
  BlockCatalog? _blockCatalog;
  LinetypeCatalog _linetypeCatalog = LinetypeCatalog.builtin();
  CtbPlotStyleTable _ctbPlotStyle = CtbPlotStyleTable.builtin();
  TextStyleCatalog _textStyleCatalog = TextStyleCatalog.builtin();
  String? _error;
  String? _status;
  bool _busy = false;
  bool _plotOptionsOpen = true;
  bool _lineworkOpen = true;
  bool _objectsOpen = false;
  bool _annotationsOpen = false;
  bool _pointsOpen = false;
  bool _lineEditMode = false;
  final List<PlotTextObject> _textObjects = [];
  String? _selectedTextId;

  @override
  void initState() {
    super.initState();
    BlockCatalogAsset.loadCached().then((c) {
      if (!mounted) return;
      setState(() => _blockCatalog = c);
    });
    LinetypeCatalog.load().then((c) {
      if (!mounted) return;
      setState(() => _linetypeCatalog = c);
    });
    CtbPlotStyleTable.load().then((c) {
      if (!mounted) return;
      setState(() => _ctbPlotStyle = c);
    });
    TextStyleCatalog.load().then((c) {
      if (!mounted) return;
      setState(() => _textStyleCatalog = c);
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

  LineworkEntity? get _selectedLineworkEntity {
    final id = _selectedLineworkId;
    final lw = _linework;
    if (id == null || lw == null) return null;
    for (final e in lw.entities) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _applyLayerOverride(String layer, LineworkStyleOverride override) {
    setState(() {
      final map = Map<String, LineworkStyleOverride>.from(
        _options.layerStyleOverrides,
      );
      if (override.isEmpty) {
        map.remove(layer);
      } else {
        map[layer] = override;
      }
      _options = _options.copyWith(layerStyleOverrides: map);
      _selectedLineworkLayer = layer;
      _lineworkOpen = true;
    });
  }

  void _selectLineworkEntity(String? id) {
    setState(() {
      _selectedNodeIndex = null;
      _selectedSegmentIndex = null;
      if (id == null) {
        // Empty-canvas / deselect must clear both entity and layer highlight.
        _selectedLineworkId = null;
        _selectedLineworkLayer = null;
        return;
      }
      LineworkEntity? ent;
      for (final e in _linework?.entities ?? const []) {
        if (e.id == id) {
          ent = e;
          break;
        }
      }
      // Locked layers are not selectable from the preview.
      if (ent != null && _options.lockedLayers.contains(ent.layer)) {
        _selectedLineworkId = null;
        _selectedLineworkLayer = null;
        return;
      }
      // Layer-first workflow: selecting a line selects its layer.
      _selectedLineworkLayer = ent?.layer;
      _selectedSymbolId = null;
      _selectedLabelPointId = null;
      _selectedTextId = null;
      _lineworkOpen = true;
      _selectedLineworkId = _lineEditMode ? id : null;
    });
  }

  void _toggleLayerLock(String layer) {
    setState(() {
      final next = Set<String>.from(_options.lockedLayers);
      if (!next.add(layer)) next.remove(layer);
      _options = _options.copyWith(lockedLayers: next);
      if (next.contains(layer) && _selectedLineworkLayer == layer) {
        _selectedLineworkId = null;
        _selectedLineworkLayer = null;
      }
    });
  }

  void _explodeSelectedLinework() {
    final id = _selectedLineworkId;
    final lw = _linework;
    if (id == null || lw == null) return;
    final next = explodeEntitiesById(lw.entities, id);
    setState(() {
      _linework = lw.copyWithEntities(next);
      _selectedLineworkId = null;
      _selectedNodeIndex = null;
      _selectedSegmentIndex = null;
      _status =
          'Exploded into ${next.length - lw.entities.length + 1} segment(s)';
      _lineworkOpen = true;
    });
  }

  void _removeSelectedSegment() {
    final ent = _selectedLineworkEntity;
    final seg = _selectedSegmentIndex;
    final lw = _linework;
    if (ent == null || seg == null || lw == null) return;
    final pieces = removeSegment(ent, segmentIndex: seg);
    final next = replaceEntity(lw.entities, ent.id, pieces);
    setState(() {
      _linework = lw.copyWithEntities(next);
      _selectedLineworkId = pieces.isEmpty ? null : pieces.first.id;
      _selectedNodeIndex = null;
      _selectedSegmentIndex = null;
      _status = pieces.isEmpty
          ? 'Removed line segment'
          : 'Removed segment — ${pieces.length} piece(s) remain';
    });
  }

  void _removeSelectedNode() {
    final ent = _selectedLineworkEntity;
    final node = _selectedNodeIndex;
    final lw = _linework;
    if (ent == null || node == null || lw == null) return;
    final pieces = removeNode(ent, nodeIndex: node);
    final next = replaceEntity(lw.entities, ent.id, pieces);
    setState(() {
      _linework = lw.copyWithEntities(next);
      _selectedLineworkId = pieces.isEmpty ? null : pieces.first.id;
      _selectedNodeIndex = null;
      _selectedSegmentIndex = null;
      _status = pieces.isEmpty ? 'Removed entity' : 'Removed vertex node';
    });
  }

  void _deleteSelectedLinework() {
    final id = _selectedLineworkId;
    final lw = _linework;
    if (id == null || lw == null) return;
    final next = lw.entities.where((e) => e.id != id).toList();
    final ov = Map<String, LineworkStyleOverride>.from(
      _options.entityStyleOverrides,
    )..remove(id);
    setState(() {
      _linework = lw.copyWithEntities(next);
      _options = _options.copyWith(entityStyleOverrides: ov);
      _selectedLineworkId = null;
      _selectedNodeIndex = null;
      _selectedSegmentIndex = null;
      _status = 'Deleted linework entity';
    });
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
      _selectedTextId = null;
    });
  }

  void _moveText(String id, double easting, double northing) {
    final i = _textObjects.indexWhere((t) => t.id == id);
    if (i < 0) return;
    setState(() {
      _textObjects[i] =
          _textObjects[i].copyWith(easting: easting, northing: northing);
      _selectedTextId = id;
      _selectedSymbolId = null;
      _selectedLabelPointId = null;
      _annotationsOpen = true;
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
      pinned: true,
    );
    setState(() {
      _options = _options.copyWith(labelDrags: next);
      _selectedLabelPointId = pointId;
      _selectedSymbolId = null;
      _lineEditMode = false;
    });
  }

  /// Bake auto-spread into label offsets (unpinned) so PDF/preview match.
  void _spreadLabelsNow() {
    final pts = _chosen.isNotEmpty ? _chosen : _points;
    if (pts.isEmpty) return;
    final scale = chooseEngineeringScale(
      pts,
      linework: _chosenLinework,
      template: _options.template,
      showPointList: _options.showPointList,
      overrideFtPerInch: _options.scaleFtPerInch,
    );
    final spread = autoSpreadLabels(
      points: pts,
      format: _options.labelFormat,
      scaleFtPerInch: scale,
      existing: _options.labelDrags,
      annotationScale: _options.annotationScale,
    );
    setState(() {
      _options = _options.copyWith(
        labelDrags: spread,
        autoSpreadLabels: true,
      );
      _status =
          'Spread ${spread.length} labels (points stay fixed — only callouts move)';
    });
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
    double? opacity,
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
        opacity: opacity,
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
        _selectedLineworkId = null;
        _selectedLineworkLayer = null;
        _selectedNodeIndex = null;
        _selectedSegmentIndex = null;
        _lineworkOpen = true;
        _options = _options.copyWith(
          includeLinework: true,
          layerStyleOverrides: const {},
          entityStyleOverrides: const {},
        );
        _status =
            'Linked ${parsed.entities.length} entities on ${parsed.layers.length} layers'
            ' (${parsed.layerStyles.length} layer styles)'
            '${sizeMb >= 1 ? ' · ${sizeMb.toStringAsFixed(1)} MB' : ''}'
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
      _selectedLineworkId = null;
      _selectedLineworkLayer = null;
      _selectedNodeIndex = null;
      _selectedSegmentIndex = null;
      _options = _options.copyWith(
        layerStyleOverrides: const {},
        entityStyleOverrides: const {},
      );
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
        title: _options.titleBlock.enabled
            ? (_options.titleBlock.title.trim().isEmpty
                ? 'STAKING PLOT'
                : _options.titleBlock.title.trim())
            : 'STAKING PLOT',
        options: _options,
        linework: linework,
        symbols: symbols,
        textObjects: List<PlotTextObject>.from(_textObjects),
        blockCatalog: _blockCatalog,
        layerStyles: _linework?.layerStyles ?? const {},
        linetypeCatalog: _linetypeCatalog,
        ctbPlotStyle: _ctbPlotStyle,
        textStyleCatalog: _textStyleCatalog,
      );
      final scale = chooseEngineeringScale(
        chosen,
        linework: linework,
        symbols: symbols,
        template: _options.template,
        showPointList: _options.showPointList,
        overrideFtPerInch: _options.scaleFtPerInch,
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

    return Theme(
      data: PlotUi.theme(context),
      child: Scaffold(
      backgroundColor: PlotUi.bg,
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
                      textObjects: _textObjects,
                      blockCatalog: _blockCatalog,
                      linetypeCatalog: _linetypeCatalog,
                      ctbPlotStyle: _ctbPlotStyle,
                      textStyleCatalog: _textStyleCatalog,
                      layerStyles: _linework?.layerStyles ?? const {},
                      selectedSymbolId: _selectedSymbolId,
                      selectedLabelPointId: _selectedLabelPointId,
                      selectedLineworkId: _selectedLineworkId,
                      selectedLineworkLayer: _selectedLineworkLayer,
                      selectedTextId: _selectedTextId,
                      selectedNodeIndex: _selectedNodeIndex,
                      selectedSegmentIndex: _selectedSegmentIndex,
                      onSelectSymbol: (id) => setState(() {
                        _selectedSymbolId = id;
                        if (id != null) {
                          _selectedLabelPointId = null;
                          _selectedLineworkId = null;
                          _selectedLineworkLayer = null;
                          _selectedTextId = null;
                          _selectedNodeIndex = null;
                          _selectedSegmentIndex = null;
                          _objectsOpen = true;
                        }
                      }),
                      onSelectLabelPoint: (id) => setState(() {
                        _selectedLabelPointId = id;
                        if (id != null) {
                          _selectedSymbolId = null;
                          _selectedLineworkId = null;
                          _selectedLineworkLayer = null;
                          _selectedTextId = null;
                          _selectedNodeIndex = null;
                          _selectedSegmentIndex = null;
                        }
                      }),
                      onSelectLinework: _selectLineworkEntity,
                      onSelectText: (id) => setState(() {
                        _selectedTextId = id;
                        if (id != null) {
                          _selectedSymbolId = null;
                          _selectedLabelPointId = null;
                          _selectedLineworkId = null;
                          _selectedLineworkLayer = null;
                          _annotationsOpen = true;
                        }
                      }),
                      onSelectNode: (i) => setState(() {
                        _selectedNodeIndex = i;
                        if (i != null) _selectedSegmentIndex = null;
                      }),
                      onSelectSegment: (i) => setState(() {
                        _selectedSegmentIndex = i;
                        if (i != null) _selectedNodeIndex = null;
                      }),
                      onMoveSymbol: _moveSymbol,
                      onMoveLabel: _moveLabel,
                      onMoveText: _moveText,
                      lineEditMode: _lineEditMode,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy || previewPoints.isEmpty
                              ? null
                              : _spreadLabelsNow,
                          icon: const Icon(Icons.scatter_plot_outlined, size: 16),
                          label: const Text('Spread', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        FilterChip(
                          label: Text(
                            _lineEditMode ? 'Trim ON' : 'Trim',
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _lineEditMode,
                          visualDensity: VisualDensity.compact,
                          onSelected: _busy || _linework == null
                              ? null
                              : (v) => setState(() {
                                    _lineEditMode = v;
                                    if (v) {
                                      _selectedLabelPointId = null;
                                      _selectedSymbolId = null;
                                      _lineworkOpen = true;
                                    } else {
                                      _selectedLineworkId = null;
                                      _selectedNodeIndex = null;
                                      _selectedSegmentIndex = null;
                                    }
                                  }),
                        ),
                        if (_options.labelDrags.isNotEmpty)
                          TextButton(
                            onPressed: _busy ? null : _resetLabelDrags,
                            child: const Text('Reset labels'),
                          ),
                      ],
                    ),
                    if (selectedLabel != null) ...[
                      const SizedBox(height: 8),
                      PointPropertiesPanel(
                        point: selectedLabel,
                        options: _options,
                        onOptions: (o) => setState(() => _options = o),
                        onClose: () =>
                            setState(() => _selectedLabelPointId = null),
                      ),
                    ],
                    if (selectedSym != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        decoration: BoxDecoration(
                          color: PlotUi.card,
                          border: Border.all(color: PlotUi.border),
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
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showPlotColorPicker(
                                      context: context,
                                      currentArgb: selectedSym.colorArgb,
                                      ctb: _ctbPlotStyle,
                                      title: 'Object color',
                                    );
                                    if (picked == null || picked.argb == 0) {
                                      return;
                                    }
                                    _updateSelectedSymbol(
                                      colorArgb: picked.argb,
                                    );
                                  },
                                  icon: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Color(selectedSym.colorArgb),
                                      border: Border.all(color: PlotUi.border),
                                    ),
                                  ),
                                  label: const Text(
                                    'Color',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                for (final c in PlotSymbolColor.presets.take(6))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: GestureDetector(
                                      onTap: () => _updateSelectedSymbol(
                                        colorArgb: c.argb,
                                      ),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Color(c.argb),
                                          border: Border.all(
                                            color: selectedSym.colorArgb ==
                                                    c.argb
                                                ? PlotUi.selection
                                                : PlotUi.border,
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
                            Row(
                              children: [
                                const Text('Opacity',
                                    style: TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Slider(
                                    value: selectedSym.opacity.clamp(0.05, 1.0),
                                    min: 0.05,
                                    max: 1.0,
                                    onChanged: (v) =>
                                        _updateSelectedSymbol(opacity: v),
                                  ),
                                ),
                                Text(
                                  '${(selectedSym.opacity * 100).round()}%',
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
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    sliver: SliverList.list(
                      children: [
                        TextField(
                          controller: _jobCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Job name',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _importCsv,
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: Text(
                                  _sourceName == null
                                      ? 'Import CSV'
                                      : 'CSV',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _linkDxf,
                                icon: const Icon(Icons.polyline, size: 16),
                                label: Text(
                                  _dxfName == null ? 'Link DXF' : 'DXF',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                            if (_dxfName != null)
                              IconButton(
                                tooltip: 'Clear DXF',
                                onPressed: _busy ? null : _clearDxf,
                                icon: const Icon(Icons.close, size: 18),
                              ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
                        ],
                        if (_status != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _status!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  if (_points.isNotEmpty) ...[
                    StickySectionSliver(
                      title: 'PLOT OPTIONS',
                      expanded: _plotOptionsOpen,
                      onToggle: () => setState(
                        () => _plotOptionsOpen = !_plotOptionsOpen,
                      ),
                      children: [
                        DropdownButtonFormField<AnsiSheetSize>(
                          value: _options.template.size,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sheet size',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final s in AnsiSheetSize.values)
                              DropdownMenuItem(
                                value: s,
                                child: Text(s.pickerLabel),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _options = _options.copyWith(
                                      template: composePlotTemplate(
                                        size: v,
                                        orientation:
                                            _options.template.orientation,
                                        layout: _options.template.layout,
                                      ),
                                    );
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<SheetOrientation>(
                          value: _options.template.orientation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Orientation',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final o in SheetOrientation.values)
                              DropdownMenuItem(
                                value: o,
                                child: Text(o.label),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _options = _options.copyWith(
                                      template: composePlotTemplate(
                                        size: _options.template.size,
                                        orientation: v,
                                        layout: _options.template.layout,
                                      ),
                                    );
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PlotTemplateLayout>(
                          value: _options.template.layout,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sheet style',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final l in PlotTemplateLayout.values)
                              DropdownMenuItem(
                                value: l,
                                child: Text(l.label),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _options = _options.copyWith(
                                      template: composePlotTemplate(
                                        size: _options.template.size,
                                        orientation:
                                            _options.template.orientation,
                                        layout: v,
                                      ),
                                    );
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final selected = _textStyleCatalog
                                .resolve(_options.textStyleId);
                            return InputDecorator(
                              decoration: InputDecoration(
                                labelText:
                                    'Text style (${_textStyleCatalog.styles.length})',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: const Icon(Icons.search, size: 20),
                              ),
                              child: InkWell(
                                onTap: _busy
                                    ? null
                                    : () async {
                                        final id =
                                            await showTextStylePickerSheet(
                                          context: context,
                                          catalog: _textStyleCatalog,
                                          selectedId: selected.id,
                                        );
                                        if (id == null || !mounted) return;
                                        setState(
                                          () => _options = _options.copyWith(
                                            textStyleId: id,
                                          ),
                                        );
                                      },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    selected.pickerLabel,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: selected.flutterFamily,
                                      fontWeight: selected.flutterWeight,
                                      fontStyle: selected.flutterStyle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PointMarkerStyle>(
                          value: _options.markerStyle,
                          decoration: const InputDecoration(
                            labelText: 'Marker',
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
                        const SizedBox(height: 8),
                        Text(
                          'DEFAULT LABEL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final f in PointLabelFormat.values)
                              ChoiceChip(
                                label: Text(
                                  f.label,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: _options.labelFormat == f,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onSelected: _busy
                                    ? null
                                    : (_) => setState(
                                          () => _options = _options.copyWith(
                                            labelFormat: f,
                                          ),
                                        ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : _pickEngineeringScale,
                                child: Text(
                                  _options.scaleFtPerInch == null
                                      ? 'Scale: Auto'
                                      : 'Scale: ${engineeringScaleLabel(_options.scaleFtPerInch!)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Annot.', style: TextStyle(fontSize: 12)),
                            SizedBox(
                              width: 110,
                              child: Slider(
                                value: _options.annotationScale.clamp(0.6, 3.0),
                                min: 0.6,
                                max: 3.0,
                                divisions: 24,
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(
                                          () => _options = _options.copyWith(
                                            annotationScale: v,
                                          ),
                                        ),
                              ),
                            ),
                            Text(
                              '${_options.annotationScale.toStringAsFixed(1)}×',
                              style: PlotUi.tiny,
                            ),
                          ],
                        ),
                        Text(
                          'Engineering scale sets plan 1"=N\'. Annot. only '
                          'resizes point labels/markers.',
                          style: PlotUi.tiny,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Auto-spread labels',
                              style: TextStyle(fontSize: 13)),
                          value: _options.autoSpreadLabels,
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                    () => _options = _options.copyWith(
                                      autoSpreadLabels: v,
                                    ),
                                  ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Point list table',
                              style: TextStyle(fontSize: 13)),
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
                          dense: true,
                          title: const Text('Object labels',
                              style: TextStyle(fontSize: 13)),
                          value: _options.showObjectLabels,
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                    () => _options = _options.copyWith(
                                      showObjectLabels: v,
                                    ),
                                  ),
                        ),
                      ],
                    ),
                    if (lw != null)
                      StickySectionSliver(
                        title:
                            'LAYERS  (${_selectedLayers.length}/${lw.layers.length})',
                        expanded: _lineworkOpen,
                        onToggle: () => setState(
                          () => _lineworkOpen = !_lineworkOpen,
                        ),
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Draw DXF linework',
                                style: TextStyle(fontSize: 13)),
                            value: _options.includeLinework,
                            onChanged: _busy
                                ? null
                                : (v) => setState(
                                      () => _options = _options.copyWith(
                                        includeLinework: v,
                                      ),
                                    ),
                          ),
                          if (_options.includeLinework)
                            LayerPropertiesManager(
                              layers: lw.layers,
                              layerStyles: lw.layerStyles,
                              selectedLayers: _selectedLayers,
                              lockedLayers: _options.lockedLayers,
                              layerOverrides: _options.layerStyleOverrides,
                              catalog: _linetypeCatalog,
                              ctb: _ctbPlotStyle,
                              globalLinetypeScale: _options.globalLinetypeScale,
                              selectedLayer: _selectedLineworkLayer,
                              entityCounts: {
                                for (final layer in lw.layers)
                                  layer: lw.countForLayer(layer),
                              },
                              onToggleLayer: (layer) => setState(() {
                                if (_selectedLayers.contains(layer)) {
                                  _selectedLayers.remove(layer);
                                } else {
                                  _selectedLayers.add(layer);
                                }
                                _selectedLineworkLayer = layer;
                                _selectedLineworkId = null;
                              }),
                              onToggleLock: _toggleLayerLock,
                              onSelectLayer: (layer) => setState(() {
                                if (_options.lockedLayers.contains(layer)) {
                                  return;
                                }
                                _selectedLineworkLayer = layer;
                                _selectedLineworkId = null;
                                _selectedNodeIndex = null;
                                _selectedSegmentIndex = null;
                                _selectedLabelPointId = null;
                                _selectedSymbolId = null;
                              }),
                              onApplyLayerOverride: _applyLayerOverride,
                              onGlobalLinetypeScale: (v) => setState(
                                () => _options = _options.copyWith(
                                  globalLinetypeScale: v,
                                ),
                              ),
                              onSelectAll: () => _selectAllLayers(!allLayers),
                            ),
                          if (_lineEditMode &&
                              _selectedLineworkEntity != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'TRIM: ${_selectedLineworkEntity!.layer} · '
                              '${_selectedLineworkEntity!.type}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : _explodeSelectedLinework,
                                  child: const Text('Explode'),
                                ),
                                TextButton(
                                  onPressed: _busy ||
                                          _selectedSegmentIndex == null
                                      ? null
                                      : _removeSelectedSegment,
                                  child: const Text('Del seg'),
                                ),
                                TextButton(
                                  onPressed: _busy ||
                                          _selectedNodeIndex == null
                                      ? null
                                      : _removeSelectedNode,
                                  child: const Text('Del node'),
                                ),
                                TextButton(
                                  onPressed:
                                      _busy ? null : _deleteSelectedLinework,
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    StickySectionSliver(
                      title: 'OBJECTS  (${_symbols.length})',
                      expanded: _objectsOpen,
                      onToggle: () =>
                          setState(() => _objectsOpen = !_objectsOpen),
                      trailing: _symbols.isEmpty
                          ? null
                          : TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _symbols.clear();
                                        _selectedSymbolId = null;
                                      }),
                              child: const Text('Clear',
                                  style: TextStyle(fontSize: 12)),
                            ),
                      children: [
                        Text(
                          'Objects scale independently (object scale × paper size). '
                          'Annotation scale does not affect them.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Paper', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: _options.symbolPaperInches
                                    .clamp(0.12, 0.8),
                                min: 0.12,
                                max: 0.8,
                                divisions: 17,
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(
                                          () => _options = _options.copyWith(
                                            symbolPaperInches: v,
                                          ),
                                        ),
                              ),
                            ),
                            Text(
                              '${_options.symbolPaperInches.toStringAsFixed(2)}"',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _addSymbol,
                          icon: const Icon(Icons.add_box_outlined, size: 16),
                          label: const Text('Add object'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                        ..._symbols.asMap().entries.map((entry) {
                          final i = entry.key;
                          final sym = entry.value;
                          final selected = sym.id == _selectedSymbolId;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            selected: selected,
                            onTap: () => setState(() {
                              _selectedSymbolId = sym.id;
                              _selectedLabelPointId = null;
                            }),
                            leading: SizedBox(
                              width: 28,
                              height: 28,
                              child: CustomPaint(
                                painter: sym.kind != null
                                    ? SymbolPreviewPainter(
                                        sym.kind!,
                                        color: Color(sym.colorArgb),
                                      )
                                    : SymbolPreviewPainter(
                                        PlotSymbolKind.hub,
                                        color: Color(sym.colorArgb),
                                      ),
                              ),
                            ),
                            title: Text(
                              sym.libraryLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${sym.scale.toStringAsFixed(2)}×',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed:
                                      _busy ? null : () => _editSymbol(i),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                ),
                                IconButton(
                                  onPressed:
                                      _busy ? null : () => _removeSymbol(i),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    StickySectionSliver(
                      title:
                          'TITLE / TEXT  (${_textObjects.length})',
                      expanded: _annotationsOpen,
                      onToggle: () => setState(
                        () => _annotationsOpen = !_annotationsOpen,
                      ),
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Title block',
                              style: TextStyle(fontSize: 13)),
                          value: _options.titleBlock.enabled,
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                    () => _options = _options.copyWith(
                                      titleBlock:
                                          _options.titleBlock.copyWith(
                                        enabled: v,
                                      ),
                                    ),
                                  ),
                        ),
                        if (_options.titleBlock.enabled) ...[
                          TextFormField(
                            initialValue: _options.titleBlock.title,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(
                              () => _options = _options.copyWith(
                                titleBlock:
                                    _options.titleBlock.copyWith(title: v),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: _options.titleBlock.project,
                            decoration: const InputDecoration(
                              labelText: 'Project',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(
                              () => _options = _options.copyWith(
                                titleBlock:
                                    _options.titleBlock.copyWith(project: v),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _options.titleBlock.drawnBy,
                                  decoration: const InputDecoration(
                                    labelText: 'Drawn by',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setState(
                                    () => _options = _options.copyWith(
                                      titleBlock: _options.titleBlock
                                          .copyWith(drawnBy: v),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _options.titleBlock.checkedBy,
                                  decoration: const InputDecoration(
                                    labelText: 'Checked by',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setState(
                                    () => _options = _options.copyWith(
                                      titleBlock: _options.titleBlock
                                          .copyWith(checkedBy: v),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _options.titleBlock.sheet,
                                  decoration: const InputDecoration(
                                    labelText: 'Sheet',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setState(
                                    () => _options = _options.copyWith(
                                      titleBlock: _options.titleBlock
                                          .copyWith(sheet: v),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _options.titleBlock.revision,
                                  decoration: const InputDecoration(
                                    labelText: 'Rev',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setState(
                                    () => _options = _options.copyWith(
                                      titleBlock: _options.titleBlock
                                          .copyWith(revision: v),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: _options.titleBlock.notes,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(
                              () => _options = _options.copyWith(
                                titleBlock:
                                    _options.titleBlock.copyWith(notes: v),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy || previewPoints.isEmpty
                              ? null
                              : () {
                                  final pts = previewPoints;
                                  final e = pts
                                          .map((p) => p.easting)
                                          .reduce((a, b) => a + b) /
                                      pts.length;
                                  final n = pts
                                          .map((p) => p.northing)
                                          .reduce((a, b) => a + b) /
                                      pts.length;
                                  final id =
                                      'txt_${DateTime.now().millisecondsSinceEpoch}';
                                  setState(() {
                                    _textObjects.add(
                                      PlotTextObject(
                                        id: id,
                                        text: 'TEXT',
                                        easting: e,
                                        northing: n,
                                      ),
                                    );
                                    _selectedTextId = id;
                                    _annotationsOpen = true;
                                  });
                                },
                          icon: const Icon(Icons.text_fields, size: 16),
                          label: const Text('Add text object'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                        ..._textObjects.map((t) {
                          final selected = t.id == _selectedTextId;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            selected: selected,
                            onTap: () =>
                                setState(() => _selectedTextId = t.id),
                            title: Text(
                              t.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${t.scale.toStringAsFixed(2)}× · ${t.effectiveFontSizePt.toStringAsFixed(0)}pt',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => setState(() {
                                _textObjects.removeWhere((x) => x.id == t.id);
                                if (_selectedTextId == t.id) {
                                  _selectedTextId = null;
                                }
                              }),
                            ),
                          );
                        }),
                        if (_selectedTextId != null) ...[
                          Builder(
                            builder: (context) {
                              final i = _textObjects
                                  .indexWhere((t) => t.id == _selectedTextId);
                              if (i < 0) return const SizedBox.shrink();
                              final t = _textObjects[i];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    key: ValueKey('txt-${t.id}'),
                                    initialValue: t.text,
                                    decoration: const InputDecoration(
                                      labelText: 'Text',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => setState(() {
                                      _textObjects[i] = t.copyWith(text: v);
                                    }),
                                  ),
                                  Row(
                                    children: [
                                      const Text('Scale',
                                          style: TextStyle(fontSize: 12)),
                                      Expanded(
                                        child: Slider(
                                          value: t.scale.clamp(0.25, 5.0),
                                          min: 0.25,
                                          max: 5.0,
                                          divisions: 19,
                                          onChanged: (v) => setState(() {
                                            _textObjects[i] =
                                                t.copyWith(scale: v);
                                          }),
                                        ),
                                      ),
                                      Text(
                                        '${t.scale.toStringAsFixed(2)}×',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Text('Opacity',
                                          style: TextStyle(fontSize: 12)),
                                      Expanded(
                                        child: Slider(
                                          value: t.opacity.clamp(0.05, 1.0),
                                          min: 0.05,
                                          max: 1.0,
                                          onChanged: (v) => setState(() {
                                            _textObjects[i] =
                                                t.copyWith(opacity: v);
                                          }),
                                        ),
                                      ),
                                      Text(
                                        '${(t.opacity * 100).round()}%',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Drag text on the preview to move it.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    StickySectionSliver(
                      title:
                          'POINTS  (${_selected.length}/${_points.length})',
                      expanded: _pointsOpen,
                      onToggle: () =>
                          setState(() => _pointsOpen = !_pointsOpen),
                      trailing: TextButton(
                        onPressed: () => _selectAll(!allSelected),
                        child: Text(
                          allSelected ? 'Clear' : 'All',
                          style: const TextStyle(fontSize: 12),
                        ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'N ${pt.northingText}  E ${pt.eastingText}  Z ${pt.elevText}',
                              style: TextStyle(
                                fontSize: 11,
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
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                    label: const Text('Create PDF'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
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
                      minimumSize: const Size.fromHeight(42),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _pickEngineeringScale() async {
    final current = _options.scaleFtPerInch;
    final auto = chooseEngineeringScale(
      _chosen.isNotEmpty ? _chosen : _points,
      linework: _chosenLinework,
      symbols: _symbols,
      template: _options.template,
      showPointList: _options.showPointList,
    );
    final picked = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PlotUi.card,
      builder: (ctx) {
        final customCtrl = TextEditingController(
          text: (current ?? auto).round().toString(),
        );
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Engineering scale',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: Text('Auto (${engineeringScaleLabel(auto)})'),
                  trailing: current == null
                      ? const Icon(Icons.check, color: PlotUi.selection)
                      : null,
                  onTap: () => Navigator.pop(ctx, -1.0),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      for (final s in kEngineeringScalePresets)
                        ListTile(
                          dense: true,
                          title: Text(engineeringScaleLabel(s)),
                          trailing: current == s
                              ? const Icon(Icons.check, color: PlotUi.selection)
                              : null,
                          onTap: () => Navigator.pop(ctx, s),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Custom ft per inch',
                            prefixText: '1"= ',
                            suffixText: "'",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final v = double.tryParse(customCtrl.text.trim());
                          if (v == null || v <= 0) return;
                          Navigator.pop(ctx, v);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (picked < 0) {
        _options = _options.copyWith(clearScaleFtPerInch: true);
      } else {
        _options = _options.copyWith(scaleFtPerInch: picked);
      }
    });
  }
}

