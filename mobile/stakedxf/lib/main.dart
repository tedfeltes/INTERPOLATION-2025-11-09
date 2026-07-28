import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'converter.dart';
import 'points/export_points_screen.dart';
import 'points/plot_ui_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StakeDxfApp());
}

class StakeDxfApp extends StatelessWidget {
  const StakeDxfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StakeDXF',
      debugShowCheckedModeBanner: false,
      theme: PlotUi.theme(context),
      builder: (context, child) => Theme(
        data: PlotUi.theme(context),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlotUi.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _InstrumentRibbon(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  // Hero mark — heavy, oversized, mono line below like a device
                  // model number rather than marketing copy.
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: PlotUi.fg,
                        height: 0.95,
                        letterSpacing: -1.5,
                      ),
                      children: [
                        TextSpan(text: 'STAKE'),
                        TextSpan(
                          text: 'DXF',
                          style: TextStyle(color: PlotUi.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'FIELD-KIT / TSC5 / TRIMBLE',
                    style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg),
                  ),
                  const SizedBox(height: 22),
                  _SectionRule(label: 'OPERATIONS'),
                  const SizedBox(height: 10),
                  _ActionRail(
                    tag: '01',
                    title: 'CONVERT',
                    detail: 'DWG → DXF · Civil 3D linework recovery',
                    icon: Icons.polyline,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ConvertDwgPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ActionRail(
                    tag: '02',
                    title: 'PLOT',
                    detail: 'Points + linework → scaled staking PDF',
                    icon: Icons.grid_on,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExportPointsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionRule(label: 'STATUS'),
                  const SizedBox(height: 10),
                  const _StatusGrid(),
                ],
              ),
            ),
            const _BottomIdBar(),
          ],
        ),
      ),
    );
  }
}

/// Top ribbon: brand mark ident + telemetry pill (like a device readout).
class _InstrumentRibbon extends StatelessWidget {
  const _InstrumentRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: PlotUi.card,
        border: Border(bottom: BorderSide(color: PlotUi.border)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: PlotUi.accent),
          const SizedBox(width: 10),
          Text('SDX', style: PlotUi.monoLabel.copyWith(color: PlotUi.fg)),
          const SizedBox(width: 8),
          Text('·', style: PlotUi.monoLabel),
          const SizedBox(width: 8),
          Text('v1.22', style: PlotUi.mono),
          const Spacer(),
          _TelemetryChip(label: 'ONLINE', ok: true),
          const SizedBox(width: 8),
          _TelemetryChip(label: 'LOCAL'),
        ],
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  const _TelemetryChip({required this.label, this.ok = false});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: ok ? PlotUi.ok : PlotUi.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            color: ok ? PlotUi.ok : PlotUi.mutedFg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: PlotUi.monoLabel.copyWith(
              color: ok ? PlotUi.ok : PlotUi.mutedFg,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: PlotUi.monoLabel),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: PlotUi.border)),
      ],
    );
  }
}

/// A rugged full-width action bar with a numeric tag, thick left rail, and
/// an outlined arrow — reads as a hardware toggle, not a card.
class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.tag,
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String tag;
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PlotUi.card,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: PlotUi.accentDim,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: PlotUi.border),
              bottom: BorderSide(color: PlotUi.border),
              left: BorderSide(color: PlotUi.accent, width: 4),
              right: BorderSide(color: PlotUi.border),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(tag, style: PlotUi.monoLabel),
              ),
              Container(width: 1, height: 44, color: PlotUi.border),
              const SizedBox(width: 14),
              Icon(icon, color: PlotUi.accent, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: PlotUi.fg,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: PlotUi.mono.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 20,
                color: PlotUi.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _StatusCell(label: 'ENGINE', value: 'LIBREDWG')),
        SizedBox(width: 1),
        Expanded(child: _StatusCell(label: 'OUTPUT', value: 'DXF R2010')),
        SizedBox(width: 1),
        Expanded(child: _StatusCell(label: 'MODE', value: 'ON-DEVICE')),
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: PlotUi.card,
        border: Border.all(color: PlotUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PlotUi.monoLabel),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PlotUi.fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomIdBar extends StatelessWidget {
  const _BottomIdBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: PlotUi.card,
        border: Border(top: BorderSide(color: PlotUi.border)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('TRIO / FIELD OPS', style: PlotUi.monoLabel),
          Text('NO CLOUD · NO TRACKING', style: PlotUi.monoLabel),
        ],
      ),
    );
  }
}

class ConvertDwgPage extends StatefulWidget {
  const ConvertDwgPage({super.key});

  @override
  State<ConvertDwgPage> createState() => _ConvertDwgPageState();
}

class _ConvertDwgPageState extends State<ConvertDwgPage> {
  final _converter = NativeConverter();
  String? _inputPath;
  String? _inputName;
  ConvertResult? _result;
  String? _error;
  bool _busy = false;
  String? _progressMessage;
  int _progressPercent = 0;
  final Set<String> _selectedLayers = {};

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _result = null;
      _selectedLayers.clear();
    });
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final path = file.path;
    if (path == null) {
      setState(() => _error = 'Could not access that file path.');
      return;
    }
    final lower = path.toLowerCase();
    if (!lower.endsWith('.dwg') && !lower.endsWith('.dxf')) {
      setState(() => _error = 'Pick a .dwg or .dxf file.');
      return;
    }
    setState(() {
      _inputPath = path;
      _inputName = file.name;
    });
  }

  Future<void> _convert() async {
    final input = _inputPath;
    if (input == null) {
      setState(() => _error = 'Choose a DWG first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _progressMessage = 'Starting conversion…';
      _progressPercent = 0;
      _selectedLayers.clear();
    });
    try {
      if (Platform.isAndroid) {
        // Needed so the conversion foreground notification can show (API 33+).
        await Permission.notification.request();
      }
      final dir = await getTemporaryDirectory();
      final stem = p.basenameWithoutExtension(input);
      final output = p.join(dir.path, '${stem}_trimble_access.dxf');
      final result = await _converter.convertFile(
        inputPath: input,
        outputPath: output,
        onProgress: (stage, percent, message) {
          if (!mounted) return;
          setState(() {
            _progressPercent = percent;
            _progressMessage = message.isEmpty ? stage : message;
          });
        },
      );
      final outFile = File(result.outputPath);
      if (!outFile.existsSync()) {
        throw Exception(
          result.message.isNotEmpty
              ? result.message
              : 'Conversion produced no DXF',
        );
      }
      final docs = await getApplicationDocumentsDirectory();
      final durable = p.join(docs.path, p.basename(output));
      await outFile.copy(durable);

      var layers = result.layers;
      if (layers.isEmpty && File(durable).existsSync()) {
        layers = await _converter.listLayers(durable);
      }

      if (!mounted) return;
      setState(() {
        _result = result.copyWith(outputPath: durable, layers: layers);
        _selectedLayers
          ..clear()
          ..addAll(layers.map((l) => l.name));
        _progressMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressMessage = null;
        });
      }
    }
  }

  Future<void> _exportSelected() async {
    final result = _result;
    if (result == null) return;
    if (_selectedLayers.isEmpty) {
      setState(() => _error = 'Select at least one layer to export.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final stem = p.basenameWithoutExtension(result.outputPath);
      final filteredPath = p.join(dir.path, '${stem}_selected.dxf');
      final filtered = await _converter.filterLayers(
        inputPath: result.outputPath,
        outputPath: filteredPath,
        layerNames: _selectedLayers,
      );
      final docs = await getApplicationDocumentsDirectory();
      final durable = p.join(docs.path, p.basename(filteredPath));
      await File(filtered.outputPath).copy(durable);
      await Share.shareXFiles(
        [XFile(durable, mimeType: 'application/dxf')],
        text:
            'Trimble Access DXF — ${_selectedLayers.length} selected layer(s)',
      );
      if (!mounted) return;
      setState(() {
        _result = filtered.copyWith(outputPath: durable);
        _selectedLayers
          ..clear()
          ..addAll(filtered.layers.map((l) => l.name));
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _shareAll() async {
    final result = _result;
    if (result == null) return;
    await Share.shareXFiles(
      [XFile(result.outputPath, mimeType: 'application/dxf')],
      text: 'Trimble Access stakeout DXF',
    );
  }

  void _selectAllLayers(bool select) {
    final layers = _result?.layers ?? const <LayerInfo>[];
    setState(() {
      _selectedLayers
        ..clear()
        ..addAll(select ? layers.map((l) => l.name) : const <String>[]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final layers = _result?.layers ?? const <LayerInfo>[];
    final selectedCount = _selectedLayers.length;
    final allSelected =
        layers.isNotEmpty && selectedCount == layers.length;

    return Scaffold(
      backgroundColor: PlotUi.bg,
      appBar: AppBar(
        title: const Text('CONVERT / DWG → DXF'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: PlotUi.accent),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _InputSlot(
              name: _inputName,
              path: _inputPath,
              onPick: _busy ? null : _pick,
            ),
            const SizedBox(height: 10),
            _PrimaryActionButton(
              label: 'RUN CONVERT',
              icon: Icons.play_arrow,
              busy: _busy && _result == null,
              onPressed: _busy || _inputPath == null ? null : _convert,
            ),
            if (_busy && _result == null) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _progressPercent > 0 ? _progressPercent / 100.0 : null,
                minHeight: 4,
                backgroundColor: PlotUi.border,
                color: PlotUi.accent,
              ),
              const SizedBox(height: 8),
              Text(
                _progressMessage == null
                    ? 'RUNNING…'
                    : '${_progressPercent > 0 ? '${_progressPercent.toString().padLeft(3, '0')}%  ·  ' : ''}'
                        '${_progressMessage!.toUpperCase()}',
                style: PlotUi.mono.copyWith(color: PlotUi.fg),
              ),
              const SizedBox(height: 4),
              Text(
                'BACKGROUND: SAFE TO SWITCH APPS',
                style: PlotUi.monoLabel,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBlock(message: _error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 18),
              _ResultReadout(
                result: _result!,
                filename: p.basename(_result!.outputPath),
              ),
              if (layers.isNotEmpty) ...[
                const SizedBox(height: 14),
                _LayerChecklist(
                  layers: layers,
                  selected: _selectedLayers,
                  allSelected: allSelected,
                  onToggle: _busy
                      ? null
                      : (name, on) => setState(() {
                            if (on) {
                              _selectedLayers.add(name);
                            } else {
                              _selectedLayers.remove(name);
                            }
                          }),
                  onSelectAll: _busy
                      ? null
                      : () => _selectAllLayers(!allSelected),
                ),
                const SizedBox(height: 10),
                _PrimaryActionButton(
                  label: selectedCount == layers.length
                      ? 'SAVE DXF · ALL LAYERS'
                      : 'SAVE DXF · $selectedCount LAYER${selectedCount == 1 ? '' : 'S'}',
                  icon: Icons.save_alt,
                  busy: _busy,
                  onPressed:
                      _busy || _selectedLayers.isEmpty ? null : _exportSelected,
                ),
                const SizedBox(height: 8),
                _SecondaryActionButton(
                  label: 'SHARE FULL DXF',
                  icon: Icons.ios_share,
                  onPressed: _busy ? null : _shareAll,
                ),
              ] else ...[
                const SizedBox(height: 12),
                _PrimaryActionButton(
                  label: 'SAVE DXF',
                  icon: Icons.save_alt,
                  onPressed: _shareAll,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Convert page: rugged input slot showing the picked filename in mono.
class _InputSlot extends StatelessWidget {
  const _InputSlot({required this.name, required this.path, required this.onPick});
  final String? name;
  final String? path;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final loaded = name != null;
    return Material(
      color: PlotUi.card,
      child: InkWell(
        onTap: onPick,
        splashFactory: NoSplash.splashFactory,
        highlightColor: PlotUi.accentDim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: loaded ? PlotUi.accent : PlotUi.border,
              width: loaded ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                loaded ? Icons.description : Icons.folder_open,
                color: loaded ? PlotUi.accent : PlotUi.mutedFg,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loaded ? 'DRAWING' : 'NO DRAWING LOADED',
                      style: PlotUi.monoLabel,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loaded ? name! : 'TAP TO PICK .DWG OR .DXF',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: loaded ? PlotUi.fg : PlotUi.dim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (loaded && path != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        path!,
                        style: PlotUi.mono,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PlotUi.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      height: 56,
      child: Material(
        color: enabled ? PlotUi.accent : PlotUi.rail,
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          child: Row(
            children: [
              const SizedBox(width: 14),
              busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PlotUi.accentFg,
                      ),
                    )
                  : Icon(
                      icon,
                      color: enabled ? PlotUi.accentFg : PlotUi.mutedFg,
                      size: 20,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: enabled ? PlotUi.accentFg : PlotUi.mutedFg,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Container(
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: enabled ? PlotUi.accentFg : PlotUi.border,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: enabled ? PlotUi.accentFg : PlotUi.mutedFg,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 48,
      child: Material(
        color: PlotUi.card,
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled ? PlotUi.borderStrong : PlotUi.border,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(icon, color: enabled ? PlotUi.fg : PlotUi.mutedFg, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: enabled ? PlotUi.fg : PlotUi.mutedFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultReadout extends StatelessWidget {
  const _ResultReadout({required this.result, required this.filename});
  final ConvertResult result;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PlotUi.card,
        border: Border(
          top: const BorderSide(color: PlotUi.border),
          bottom: const BorderSide(color: PlotUi.border),
          right: const BorderSide(color: PlotUi.border),
          left: const BorderSide(color: PlotUi.ok, width: 4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, color: PlotUi.ok),
              const SizedBox(width: 8),
              Text('CONVERT / OK', style: PlotUi.monoLabel.copyWith(color: PlotUi.ok)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.message.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: PlotUi.fg,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _KV('STAKEABLE', result.stakeableCount.toString()),
          _KV('LAYERS', '${result.layers.length}'),
          if (result.proxyExploded > 0)
            _KV('PROXIES', result.proxyExploded.toString()),
          _KV('FILE', filename),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 76, child: Text(k, style: PlotUi.monoLabel)),
          Expanded(child: Text(v, style: PlotUi.mono.copyWith(color: PlotUi.fg))),
        ],
      ),
    );
  }
}

class _LayerChecklist extends StatelessWidget {
  const _LayerChecklist({
    required this.layers,
    required this.selected,
    required this.allSelected,
    required this.onToggle,
    required this.onSelectAll,
  });
  final List<LayerInfo> layers;
  final Set<String> selected;
  final bool allSelected;
  final void Function(String name, bool on)? onToggle;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PlotUi.card,
        border: Border.all(color: PlotUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: PlotUi.elevated,
              border: Border(bottom: BorderSide(color: PlotUi.border)),
            ),
            child: Row(
              children: [
                Text('LAYERS', style: PlotUi.monoLabel.copyWith(color: PlotUi.fg)),
                const SizedBox(width: 8),
                Text('${selected.length}/${layers.length}',
                    style: PlotUi.mono.copyWith(color: PlotUi.accent)),
                const Spacer(),
                TextButton(
                  onPressed: onSelectAll,
                  child: Text(allSelected ? 'NONE' : 'ALL'),
                ),
              ],
            ),
          ),
          for (var i = 0; i < layers.length; i++)
            InkWell(
              onTap: onToggle == null
                  ? null
                  : () => onToggle!(
                        layers[i].name,
                        !selected.contains(layers[i].name),
                      ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == layers.length - 1
                          ? Colors.transparent
                          : PlotUi.border,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _Tick(on: selected.contains(layers[i].name)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        layers[i].name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: PlotUi.fg,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Text(
                      layers[i].entityCount.toString(),
                      style: PlotUi.mono.copyWith(color: PlotUi.dim),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: on ? PlotUi.accent : Colors.transparent,
        border: Border.all(color: on ? PlotUi.accent : PlotUi.borderStrong, width: 1.4),
      ),
      alignment: Alignment.center,
      child: on
          ? const Icon(Icons.check, size: 12, color: PlotUi.accentFg)
          : null,
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PlotUi.card,
        border: Border(
          left: const BorderSide(color: PlotUi.destructive, width: 4),
          right: const BorderSide(color: PlotUi.border),
          top: const BorderSide(color: PlotUi.border),
          bottom: const BorderSide(color: PlotUi.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ERROR',
              style: PlotUi.monoLabel.copyWith(color: PlotUi.destructive)),
          const SizedBox(height: 4),
          Text(message,
              style: PlotUi.mono.copyWith(color: PlotUi.fg)),
        ],
      ),
    );
  }
}

