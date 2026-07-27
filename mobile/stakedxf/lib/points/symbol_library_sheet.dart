import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'block_catalog.dart';
import 'block_catalog_asset.dart';
import 'plot_symbols.dart';
import 'survey_point.dart';
import 'symbol_preview.dart';

/// Bottom sheet: browse library → place/edit a symbol on the plot.
///
/// Color / scale / rotation stay pinned at the bottom so DWG-block browsing
/// does not bury the controls.
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
    backgroundColor: const Color(0xFF141814),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
  BlockCatalog? _catalog;
  bool _showAdvancedLocation = false;

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
      _showAdvancedLocation = true;
    } else if (pts.isNotEmpty) {
      // Place at centroid of selected stakes — user drags on live preview.
      var e = 0.0;
      var n = 0.0;
      for (final p in pts) {
        e += p.easting;
        n += p.northing;
      }
      e /= pts.length;
      n /= pts.length;
      _anchorId = pts.first.id;
      _northCtrl = TextEditingController(text: n.toStringAsFixed(3));
      _eastCtrl = TextEditingController(text: e.toStringAsFixed(3));
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

  String get _selectedName {
    if (_category == PlotSymbolCategory.dwgBlocks) {
      return _block?.name ?? 'Select a block';
    }
    return _kind?.label ?? 'Select a symbol';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kinds = symbolsInCategory(_category);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isDwg = _category == PlotSymbolCategory.dwgBlocks;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Pick a symbol, set color/scale below, then place it. '
                'Drag on the live preview to position.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in PlotSymbolCategory.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            cat == PlotSymbolCategory.dwgBlocks
                                ? 'DWG (${_catalog?.blocks.length ?? "…"})'
                                : cat.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _category == cat,
                          onSelected: (_) {
                            setState(() {
                              _category = cat;
                              if (cat == PlotSymbolCategory.dwgBlocks) {
                                _kind = null;
                                _block ??=
                                    (_catalog?.sorted.isNotEmpty ?? false)
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isDwg)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
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
              ),
            const SizedBox(height: 8),
            Expanded(
              child: isDwg
                  ? _buildBlockGrid(cs)
                  : GridView.count(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.95,
                      children: [
                        for (final kind in kinds)
                          InkWell(
                            onTap: () => setState(() => _kind = kind),
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.zero,
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
            ),
            // Sticky attribute bar — always visible without scrolling the library.
            Material(
              color: const Color(0xFF1B281C),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: isDwg && _block != null
                              ? CustomPaint(
                                  painter: BlockPreviewPainter(
                                    _block!,
                                    color: Color(_colorArgb),
                                  ),
                                )
                              : _kind != null
                                  ? CustomPaint(
                                      painter: SymbolPreviewPainter(
                                        _kind!,
                                        color: Color(_colorArgb),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final c in PlotSymbolColor.presets)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _colorArgb = c.argb),
                                child: Container(
                                  width: 30,
                                  height: 30,
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
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            'Scale\n${_scale.toStringAsFixed(2)}×',
                            style: const TextStyle(fontSize: 11, height: 1.2),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _scale.clamp(0.25, 5.0),
                            min: 0.25,
                            max: 5.0,
                            divisions: 19,
                            onChanged: (v) => setState(() => _scale = v),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            'Rotate\n${_rotation.toStringAsFixed(0)}°',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, height: 1.2),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _rotation.clamp(-180, 180),
                            min: -180,
                            max: 180,
                            divisions: 72,
                            onChanged: (v) => setState(() => _rotation = v),
                          ),
                        ),
                      ],
                    ),
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _showAdvancedLocation,
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          'Location / label (optional)',
                          style: TextStyle(fontSize: 13),
                        ),
                        children: [
                          if (widget.anchorPoints.isNotEmpty)
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
                              onChanged: (v) =>
                                  setState(() => _applyAnchor(v)),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _northCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.\-]'),
                                    ),
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
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.\-]'),
                                    ),
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
                          TextField(
                            controller: _labelCtrl,
                            decoration: InputDecoration(
                              labelText: 'Label (optional)',
                              hintText: _selectedName,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check),
                      label: Text(
                        widget.existing == null
                            ? 'Place on plot — then drag to position'
                            : 'Update object',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockGrid(ColorScheme cs) {
    final blocks = _filteredBlocks;
    if (_catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (blocks.isEmpty) {
      return Center(
        child: Text(
          'No blocks match that filter.',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${blocks.length} block${blocks.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: blocks.length,
            itemBuilder: (context, index) {
              final block = blocks[index];
              final selected = _block?.id == block.id;
              return InkWell(
                onTap: () => setState(() => _block = block),
                borderRadius: BorderRadius.zero,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: selected ? cs.primary : const Color(0x59E4572E),
                      width: selected ? 2 : 1,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
