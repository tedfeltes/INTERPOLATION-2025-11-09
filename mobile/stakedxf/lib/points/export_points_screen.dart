import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'block_catalog.dart';
import 'block_catalog_asset.dart';
import 'csv_io.dart';
import 'dxf_linework.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_symbols.dart';
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
  BlockCatalog? _blockCatalog;
  String? _error;
  String? _status;
  bool _busy = false;

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
    return lw.forLayers(_selectedLayers);
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
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final lower = file.name.toLowerCase();
    if (!lower.endsWith('.dxf')) {
      setState(() => _error = 'Pick a .dxf file to link as plot linework.');
      return;
    }

    String? text =
        file.bytes != null ? utf8.decode(file.bytes!, allowMalformed: true) : null;
    if ((text == null || text.trim().isEmpty) && file.path != null) {
      text = await File(file.path!).readAsString();
    }
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = 'Could not read that DXF.');
      return;
    }

    final parsed = parseDxfLinework(text);
    if (parsed.entities.isEmpty) {
      setState(
        () => _error =
            'No LINE / LWPOLYLINE / ARC / CIRCLE linework found in that DXF.',
      );
      return;
    }

    setState(() {
      _linework = parsed;
      _dxfName = file.name;
      _selectedLayers
        ..clear()
        ..addAll(parsed.layers);
      _options = _options.copyWith(includeLinework: true);
      _status =
          'Linked ${parsed.entities.length} entities on ${parsed.layers.length} layers';
    });
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
      _status = 'Added ${placed.libraryLabel} to plot';
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
      _status = 'Updated ${placed.libraryLabel}';
    });
  }

  void _removeSymbol(int index) {
    if (index < 0 || index >= _symbols.length) return;
    final removed = _symbols.removeAt(index);
    setState(() => _status = 'Removed ${removed.libraryLabel}');
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
      ).round();
      final docs = await getApplicationDocumentsDirectory();
      final stem = _jobCtrl.text.trim().isEmpty
          ? 'staking_plot'
          : _jobCtrl.text.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
      final out = File(p.join(docs.path, '${stem}_staking_plot.pdf'));
      await out.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(out.path, mimeType: 'application/pdf')],
        text: 'Staking plot 1"=$scale\'',
      );
      final lwNote = linework.isEmpty ? '' : ', ${linework.length} linework';
      final symNote =
          symbols.isEmpty ? '' : ', ${symbols.length} library object(s)';
      setState(
        () => _status =
            'Staking plot ready — ${chosen.length} points$lwNote$symNote @ 1"=$scale\'',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Points'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(
                    'Import points, customize the plot, optionally link a DXF '
                    'for linework, then create a scaled staking plot PDF.',
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
                    const SizedBox(height: 18),
                    Text(
                      'Plot options',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: cs.primary,
                      ),
                    ),
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
                          DropdownMenuItem(value: m, child: Text(m.label)),
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
                          DropdownMenuItem(value: f, child: Text(f.label)),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include point list table'),
                      subtitle: const Text(
                        'Off by default — more space for the staking plot',
                      ),
                      value: _options.showPointList,
                      onChanged: _busy
                          ? null
                          : (v) => setState(
                                () => _options =
                                    _options.copyWith(showPointList: v),
                              ),
                    ),
                    if (lw != null) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Draw linked DXF linework'),
                        value: _options.includeLinework,
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                  () => _options =
                                      _options.copyWith(includeLinework: v),
                                ),
                      ),
                      if (_options.includeLinework) ...[
                        Row(
                          children: [
                            Text(
                              'Linework layers (${_selectedLayers.length}/${lw.layers.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _selectAllLayers(!allLayers),
                              child: Text(allLayers ? 'Clear' : 'All'),
                            ),
                          ],
                        ),
                        ...lw.layers.map((layer) {
                          final count = lw.entities
                              .where((e) => e.layer == layer)
                              .length;
                          return CheckboxListTile(
                            value: _selectedLayers.contains(layer),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(layer),
                            subtitle: Text('$count entit${count == 1 ? "y" : "ies"}'),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Plot objects (${_symbols.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: cs.primary,
                          ),
                        ),
                        const Spacer(),
                        if (_symbols.isNotEmpty)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _symbols.clear()),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    Text(
                      'Add built-in symbols or any BLOCK extracted from the '
                      'project DWG. Move, scale, rotate, and recolor each instance.'
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
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
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
                                        _blockCatalog![sym.blockId!] != null)
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                              onPressed: _busy ? null : () => _editSymbol(i),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: _busy ? null : () => _removeSymbol(i),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_selected.length} of ${_points.length} points selected',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _selectAll(!allSelected),
                          child: Text(allSelected ? 'Clear' : 'Select all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._points.map((pt) {
                      final checked = _selected.contains(pt.id);
                      return CheckboxListTile(
                        value: checked,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '${pt.id}  ${pt.description}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
