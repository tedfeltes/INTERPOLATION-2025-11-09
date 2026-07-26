import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'block_catalog.dart';
import 'block_catalog_asset.dart';
import 'plot_symbols.dart';
import 'survey_point.dart';
import 'symbol_preview.dart';

/// Bottom sheet: browse library → place/edit a symbol on the plot.
Future<PlacedPlotSymbol?> showSymbolLibrarySheet({
  required BuildContext context,
  required List<SurveyPoint> anchorPoints,
  PlacedPlotSymbol? existing,
  BlockCatalog? blockCatalog,
}) {
  return showModalBottomSheet<PlacedPlotSymbol>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF152016),
    builder: (ctx) => _SymbolLibrarySheet(
      anchorPoints: anchorPoints,
      existing: existing,
      blockCatalog: blockCatalog,
    ),
  );
}

class _SymbolLibrarySheet extends StatefulWidget {
  const _SymbolLibrarySheet({
    required this.anchorPoints,
    this.existing,
    this.blockCatalog,
  });

  final List<SurveyPoint> anchorPoints;
  final PlacedPlotSymbol? existing;
  final BlockCatalog? blockCatalog;

  @override
  State<_SymbolLibrarySheet> createState() => _SymbolLibrarySheetState();
}

class _SymbolLibrarySheetState extends State<_SymbolLibrarySheet> {
  late PlotSymbolCategory _category;
  PlotSymbolKind? _kind;
  DwgBlockSymbol? _block;
  late double _scale;
  late double _rotation;
  late int _colorArgb;
  late TextEditingController _labelCtrl;
  late TextEditingController _northCtrl;
  late TextEditingController _eastCtrl;
  late TextEditingController _filterCtrl;
  String? _anchorId;
  double _nudgeFt = 25;
  BlockCatalog? _catalog;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _catalog = widget.blockCatalog;
    _scale = existing?.scale ?? 1.0;
    _rotation = existing?.rotationDeg ?? 0.0;
    _colorArgb = existing?.colorArgb ?? PlotSymbolColor.presets.first.argb;
    _labelCtrl = TextEditingController(text: existing?.label ?? '');
    _filterCtrl = TextEditingController();

    if (existing?.blockId != null) {
      _category = PlotSymbolCategory.dwgBlocks;
      _block = _catalog?[existing!.blockId!];
      _kind = null;
    } else {
      _kind = existing?.kind ?? PlotSymbolKind.fireHydrant;
      _category = _kind!.category;
      _block = null;
    }

    final pts = widget.anchorPoints;
    if (existing != null) {
      _northCtrl =
          TextEditingController(text: existing.northing.toStringAsFixed(3));
      _eastCtrl =
          TextEditingController(text: existing.easting.toStringAsFixed(3));
    } else if (pts.isNotEmpty) {
      _anchorId = pts.first.id;
      _northCtrl =
          TextEditingController(text: pts.first.northing.toStringAsFixed(3));
      _eastCtrl =
          TextEditingController(text: pts.first.easting.toStringAsFixed(3));
    } else {
      _northCtrl = TextEditingController(text: '0');
      _eastCtrl = TextEditingController(text: '0');
    }

    if (_catalog == null) {
      BlockCatalogAsset.loadCached().then((c) {
        if (!mounted) return;
        setState(() {
          _catalog = c;
          if (_category == PlotSymbolCategory.dwgBlocks && _block == null) {
            _block = c.sorted.isEmpty ? null : c.sorted.first;
          }
          if (existing?.blockId != null) {
            _block = c[existing!.blockId!];
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _northCtrl.dispose();
    _eastCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _applyAnchor(String? id) {
    _anchorId = id;
    if (id == null) return;
    SurveyPoint? pt;
    for (final p in widget.anchorPoints) {
      if (p.id == id) {
        pt = p;
        break;
      }
    }
    if (pt == null) return;
    _northCtrl.text = pt.northing.toStringAsFixed(3);
    _eastCtrl.text = pt.easting.toStringAsFixed(3);
  }

  void _nudge(double dE, double dN) {
    final e = double.tryParse(_eastCtrl.text) ?? 0;
    final n = double.tryParse(_northCtrl.text) ?? 0;
    setState(() {
      _eastCtrl.text = (e + dE).toStringAsFixed(3);
      _northCtrl.text = (n + dN).toStringAsFixed(3);
    });
  }

  void _submit() {
    final e = double.tryParse(_eastCtrl.text.trim());
    final n = double.tryParse(_northCtrl.text.trim());
    if (e == null || n == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid Northing / Easting')),
      );
      return;
    }
    final id = widget.existing?.id ?? newSymbolId();
    final PlacedPlotSymbol placed;
    if (_category == PlotSymbolCategory.dwgBlocks) {
      final block = _block;
      if (block == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a DWG block')),
        );
        return;
      }
      placed = PlacedPlotSymbol.block(
        id: id,
        blockId: block.id,
        displayName: block.name,
        defaultSizeFt: block.defaultSizeFt,
        easting: e,
        northing: n,
        scale: _scale.clamp(0.25, 5.0),
        rotationDeg: _rotation,
        colorArgb: _colorArgb,
        label: _labelCtrl.text.trim(),
      );
    } else {
      final kind = _kind;
      if (kind == null) return;
      placed = PlacedPlotSymbol.builtin(
        id: id,
        kind: kind,
        easting: e,
        northing: n,
        scale: _scale.clamp(0.25, 5.0),
        rotationDeg: _rotation,
        colorArgb: _colorArgb,
        label: _labelCtrl.text.trim(),
      );
    }
    Navigator.of(context).pop(placed);
  }

  List<DwgBlockSymbol> get _filteredBlocks {
    final all = _catalog?.sorted ?? const <DwgBlockSymbol>[];
    final q = _filterCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kinds = symbolsInCategory(_category);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isDwg = _category == PlotSymbolCategory.dwgBlocks;
    final sourceText = isDwg
        ? (_block?.source ?? 'DWG block library')
        : (_kind?.source ?? '');

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollCtrl) {
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Text(
                    widget.existing == null
                        ? 'Add plot object'
                        : 'Edit plot object',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Built-in symbols from civil details/signage, plus every BLOCK '
                'extracted from the project DWG. Place at a point or N/E, then '
                'scale, rotate, and recolor.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cat in PlotSymbolCategory.values)
                    ChoiceChip(
                      label: Text(
                        cat == PlotSymbolCategory.dwgBlocks
                            ? 'DWG blocks (${_catalog?.blocks.length ?? "…"})'
                            : cat.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _category == cat,
                      onSelected: (_) {
                        setState(() {
                          _category = cat;
                          if (cat == PlotSymbolCategory.dwgBlocks) {
                            _kind = null;
                            _block ??= (_catalog?.sorted.isNotEmpty ?? false)
                                ? _catalog!.sorted.first
                                : null;
                          } else {
                            _block = null;
                            final list = symbolsInCategory(cat);
                            if (_kind == null || !list.contains(_kind)) {
                              _kind = list.isEmpty ? null : list.first;
                            }
                          }
                        });
                      },
                    ),
                ],
              ),
              if (isDwg) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _filterCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Filter blocks',
                    hintText: 'EUWHYD, NORTH ARROW, …',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 10),
              if (isDwg)
                ..._buildBlockGrid(cs)
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
                  children: [
                    for (final kind in kinds)
                      InkWell(
                        onTap: () => setState(() => _kind = kind),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _kind == kind
                                  ? cs.primary
                                  : const Color(0x59E4572E),
                              width: _kind == kind ? 2 : 1,
                            ),
                            color: const Color(0xCC162014),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  painter: SymbolPreviewPainter(
                                    kind,
                                    color: Color(_colorArgb),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              Text(
                                kind.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Source: $sourceText',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Location',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              if (widget.anchorPoints.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _anchorId,
                  decoration: const InputDecoration(
                    labelText: 'Snap to point',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Manual N / E'),
                    ),
                    for (final pt in widget.anchorPoints)
                      DropdownMenuItem(
                        value: pt.id,
                        child: Text('${pt.id}  ${pt.description}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _applyAnchor(v)),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _northCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Northing',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _eastCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Easting',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Nudge ($_nudgeFt ft)', style: const TextStyle(fontSize: 12)),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _nudge(0, _nudgeFt),
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: 'North',
                  ),
                  IconButton(
                    onPressed: () => _nudge(0, -_nudgeFt),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'South',
                  ),
                  IconButton(
                    onPressed: () => _nudge(-_nudgeFt, 0),
                    icon: const Icon(Icons.keyboard_arrow_left),
                    tooltip: 'West',
                  ),
                  IconButton(
                    onPressed: () => _nudge(_nudgeFt, 0),
                    icon: const Icon(Icons.keyboard_arrow_right),
                    tooltip: 'East',
                  ),
                  const Spacer(),
                  DropdownButton<double>(
                    value: _nudgeFt,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 ft')),
                      DropdownMenuItem(value: 10, child: Text('10 ft')),
                      DropdownMenuItem(value: 25, child: Text('25 ft')),
                      DropdownMenuItem(value: 50, child: Text('50 ft')),
                      DropdownMenuItem(value: 100, child: Text('100 ft')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _nudgeFt = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Scale  ${_scale.toStringAsFixed(2)}×',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _scale.clamp(0.25, 5.0),
                min: 0.25,
                max: 5.0,
                divisions: 19,
                label: '${_scale.toStringAsFixed(2)}×',
                onChanged: (v) => setState(() => _scale = v),
              ),
              Text(
                'Rotation  ${_rotation.toStringAsFixed(0)}°',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _rotation.clamp(-180, 180),
                min: -180,
                max: 180,
                divisions: 72,
                label: '${_rotation.toStringAsFixed(0)}°',
                onChanged: (v) => setState(() => _rotation = v),
              ),
              const SizedBox(height: 4),
              Text('Color', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in PlotSymbolColor.presets)
                    GestureDetector(
                      onTap: () => setState(() => _colorArgb = c.argb),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c.argb),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorArgb == c.argb
                                ? Colors.white
                                : Colors.white24,
                            width: _colorArgb == c.argb ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: isDwg
                      ? (_block?.name ?? 'Block')
                      : (_kind?.label ?? 'Symbol'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: Text(
                  widget.existing == null ? 'Add to plot' : 'Update object',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBlockGrid(ColorScheme cs) {
    final blocks = _filteredBlocks;
    if (_catalog == null) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (blocks.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No blocks match that filter.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
          ),
        ),
      ];
    }
    return [
      Text(
        '${blocks.length} block${blocks.length == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurface.withValues(alpha: 0.65),
        ),
      ),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
        children: [
          for (final block in blocks)
            InkWell(
              onTap: () => setState(() => _block = block),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _block?.id == block.id
                        ? cs.primary
                        : const Color(0x59E4572E),
                    width: _block?.id == block.id ? 2 : 1,
                  ),
                  color: const Color(0xCC162014),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: BlockPreviewPainter(
                          block,
                          color: Color(_colorArgb),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Text(
                      block.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }
}
