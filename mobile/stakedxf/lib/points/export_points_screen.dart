import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'csv_io.dart';
import 'plot_pdf.dart';
import 'survey_point.dart';

/// Export Points screen — import CSV, select points, export CSV / staking plot PDF.
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
  String? _error;
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _jobCtrl.dispose();
    super.dispose();
  }

  List<SurveyPoint> get _chosen =>
      _points.where((p) => _selected.contains(p.id)).toList();

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
        ..addAll(parsed.map((p) => p.id));
      _sourceName = file.name;
      _status = 'Loaded ${parsed.length} points';
      if (_jobCtrl.text.trim().isEmpty) {
        _jobCtrl.text = p.basenameWithoutExtension(file.name).toUpperCase();
      }
    });
  }

  void _selectAll(bool value) {
    setState(() {
      _selected
        ..clear()
        ..addAll(value ? _points.map((p) => p.id) : const <String>[]);
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
      final bytes = await buildStakingPlotPdf(
        points: chosen,
        jobName: _jobCtrl.text.trim(),
      );
      final scale = chooseEngineeringScale(chosen).round();
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
      setState(
        () => _status =
            'Staking plot ready — ${chosen.length} points @ 1"=$scale\'',
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
                    'Import points from your data collector, select what you '
                    'need, then export a CSV or a scaled staking plot PDF '
                    '(control-note style).',
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
                          ? 'Import points CSV'
                          : 'Reload: $_sourceName',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_points.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${_selected.length} of ${_points.length} selected',
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
