import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'converter.dart';
import 'points/export_points_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StakeDxfApp());
}

class StakeDxfApp extends StatelessWidget {
  const StakeDxfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE4572E),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'StakeDXF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: base.copyWith(
          surface: const Color(0xFF152016),
          primary: const Color(0xFFE4572E),
        ),
        scaffoldBackgroundColor: const Color(0xFF10160F),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'StakeDXF',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recover Civil 3D linework, or build a staking plot from '
              'points on this controller.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            _CardButton(
              title: 'Convert DWG → DXF',
              subtitle: 'Recover Civil 3D linework for Trimble Access',
              icon: Icons.polyline,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConvertDwgPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            _CardButton(
              title: 'Export Points',
              subtitle: 'Select points → CSV or staking plot PDF',
              icon: Icons.pin_drop,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExportPointsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Runs entirely on this device. No cloud upload.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
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

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _result = null;
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
    });
    try {
      final dir = await getTemporaryDirectory();
      final stem = p.basenameWithoutExtension(input);
      final output = p.join(dir.path, '${stem}_trimble_access.dxf');
      final result = await _converter.convertFile(
        inputPath: input,
        outputPath: output,
      );
      final docs = await getApplicationDocumentsDirectory();
      final durable = p.join(docs.path, p.basename(output));
      await File(result.outputPath).copy(durable);
      setState(() {
        _result = ConvertResult(
          outputPath: durable,
          stakeableCount: result.stakeableCount,
          proxyExploded: result.proxyExploded,
          message: result.message,
        );
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final result = _result;
    if (result == null) return;
    await Share.shareXFiles(
      [XFile(result.outputPath, mimeType: 'application/dxf')],
      text: 'Trimble Access stakeout DXF',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convert DWG'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Import a Civil 3D DWG, recover the stakeable linework on this '
              'device, export a DXF for Trimble Access.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            _CardButton(
              title: _inputName == null ? 'Choose DWG / DXF' : _inputName!,
              subtitle: _inputName == null
                  ? 'Civil 3D drawing with linework'
                  : _inputPath,
              icon: Icons.folder_open,
              onTap: _busy ? null : _pick,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _inputPath == null ? null : _convert,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: cs.primary,
                foregroundColor: Colors.black,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text(
                      'Convert for Trimble Access',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x598FCE6B)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xBF142412),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result!.message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Stakeable entities: ${_result!.stakeableCount}'),
                    if (_result!.proxyExploded > 0)
                      Text(
                        'Civil 3D proxies exploded: ${_result!.proxyExploded}',
                      ),
                    Text(
                      p.basename(_result!.outputPath),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Save DXF'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Put the DXF in your Trimble job folder, set it as a '
                      'selectable map file, then stake the linework.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC162014),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x59E4572E)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFE4572E), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0x99E4572E)),
            ],
          ),
        ),
      ),
    );
  }
}
