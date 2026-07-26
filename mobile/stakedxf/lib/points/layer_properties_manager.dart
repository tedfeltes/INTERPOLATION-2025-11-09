import 'package:flutter/material.dart';

import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'linetype_catalog.dart';
import 'linework_style.dart';

/// Civil 3D–style Layer Properties Manager.
///
/// Each layer is one row: On · Color · LT · LW · LTS · Name.
/// Tap a cell to edit that attribute for the **whole layer**.
class LayerPropertiesManager extends StatelessWidget {
  const LayerPropertiesManager({
    super.key,
    required this.layers,
    required this.layerStyles,
    required this.selectedLayers,
    required this.layerOverrides,
    required this.catalog,
    required this.ctb,
    required this.globalLinetypeScale,
    required this.selectedLayer,
    required this.onToggleLayer,
    required this.onSelectLayer,
    required this.onApplyLayerOverride,
    required this.onGlobalLinetypeScale,
    this.onSelectAll,
    this.entityCounts = const {},
  });

  final List<String> layers;
  final Map<String, DxfLayerStyle> layerStyles;
  final Set<String> selectedLayers;
  final Map<String, LineworkStyleOverride> layerOverrides;
  final LinetypeCatalog catalog;
  final CtbPlotStyleTable ctb;
  final double globalLinetypeScale;
  final String? selectedLayer;
  final ValueChanged<String> onToggleLayer;
  final ValueChanged<String> onSelectLayer;
  final void Function(String layer, LineworkStyleOverride override)
      onApplyLayerOverride;
  final ValueChanged<double> onGlobalLinetypeScale;
  final VoidCallback? onSelectAll;
  final Map<String, int> entityCounts;

  ResolvedLineworkStyle _resolve(String layer) {
    final probe = LineworkEntity(
      id: '_layer_$layer',
      layer: layer,
      type: 'LINE',
      vertices: const [
        [0.0, 0.0],
        [1.0, 0.0],
      ],
    );
    return resolveLineworkStyle(
      entity: probe,
      catalog: catalog,
      layerStyles: layerStyles,
      layerOverrides: layerOverrides,
      globalLinetypeScale: globalLinetypeScale,
      ctb: ctb,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'LAYER PROPERTIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            if (onSelectAll != null)
              TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('All/None', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('LTS', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            Expanded(
              child: Slider(
                value: globalLinetypeScale.clamp(0.1, 10.0),
                min: 0.1,
                max: 10.0,
                onChanged: onGlobalLinetypeScale,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                globalLinetypeScale.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, fontFeatures: [
                  FontFeature.tabularFigures(),
                ]),
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              _headerRow(cs),
              for (final layer in layers) _layerRow(context, cs, layer),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a line on the preview to select its layer. Edit color, '
          'linetype, weight, and scale for the whole layer — like Civil 3D.',
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: const Row(
        children: [
          SizedBox(width: 28, child: _H('On')),
          SizedBox(width: 28, child: _H('C')),
          SizedBox(width: 44, child: _H('LT')),
          SizedBox(width: 36, child: _H('LW')),
          SizedBox(width: 36, child: _H('LTS')),
          Expanded(child: _H('Name')),
        ],
      ),
    );
  }

  Widget _layerRow(BuildContext context, ColorScheme cs, String layer) {
    final on = selectedLayers.contains(layer);
    final resolved = _resolve(layer);
    final ov = layerOverrides[layer] ?? const LineworkStyleOverride();
    final selected = layer == selectedLayer;
    final count = entityCounts[layer];
    final ltAbbrev = _ltAbbrev(resolved.linetype.name);
    final lwLabel = resolved.strokeWidthPt.toStringAsFixed(1);
    final ltsLabel = resolved.linetypeScale.toStringAsFixed(1);

    return Material(
      color: selected
          ? cs.primary.withValues(alpha: 0.12)
          : (on ? Colors.transparent : cs.surface.withValues(alpha: 0.35)),
      child: InkWell(
        onTap: () => onSelectLayer(layer),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: on,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => onToggleLayer(layer),
                ),
              ),
              SizedBox(
                width: 28,
                child: GestureDetector(
                  onTap: () => _pickColor(context, layer, ov, resolved),
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Color(resolved.colorArgb),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: _CellTap(
                  label: ltAbbrev,
                  onTap: () => _pickLinetype(context, layer, ov),
                ),
              ),
              SizedBox(
                width: 36,
                child: _CellTap(
                  label: lwLabel,
                  onTap: () => _pickLineweight(context, layer, ov),
                ),
              ),
              SizedBox(
                width: 36,
                child: _CellTap(
                  label: ltsLabel,
                  onTap: () => _pickLtScale(context, layer, ov, resolved),
                ),
              ),
              Expanded(
                child: Text(
                  count == null ? layer : '$layer  ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: on
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ltAbbrev(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'CONT';
    if (n.toUpperCase().startsWith('CONT')) return 'CONT';
    if (n.length <= 5) return n.toUpperCase();
    return n.substring(0, 4).toUpperCase();
  }

  Future<void> _pickColor(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
    ResolvedLineworkStyle resolved,
  ) async {
    const presets = <int>[
      0xFFE10600,
      0xFFFF0000,
      0xFF1565C0,
      0xFF2E7D32,
      0xFFF9A825,
      0xFF1A1A1A,
      0xFF989898,
      0xFF757575,
      0xFF00838F,
      0xFF6A1B9A,
    ];
    final picked = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Layer color — $layer',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in presets)
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: resolved.colorArgb == c
                                  ? Colors.white
                                  : Colors.white24,
                              width: resolved.colorArgb == c ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, -1),
                  child: const Text('ByLayer / CTB default'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked == -1) {
      onApplyLayerOverride(layer, ov.copyWith(clearColor: true));
    } else {
      onApplyLayerOverride(layer, ov.copyWith(colorArgb: picked));
    }
  }

  Future<void> _pickLinetype(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
  ) async {
    final names = catalog.names;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.55,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Linetype — $layer',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: names.length,
                    itemBuilder: (_, i) {
                      final n = names[i];
                      return ListTile(
                        dense: true,
                        title: Text(n),
                        onTap: () => Navigator.pop(ctx, n),
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('ByLayer default'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked.isEmpty) {
      onApplyLayerOverride(layer, ov.copyWith(clearLinetype: true));
    } else {
      onApplyLayerOverride(layer, ov.copyWith(linetypeName: picked));
    }
  }

  Future<void> _pickLineweight(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
  ) async {
    const weights = <double>[0.18, 0.25, 0.35, 0.50, 0.70, 1.00, 1.40, 2.00];
    final picked = await showModalBottomSheet<double?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Lineweight (pt) — $layer',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (final w in weights)
                ListTile(
                  dense: true,
                  title: Text(w.toStringAsFixed(2)),
                  onTap: () => Navigator.pop(ctx, w),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, -1.0),
                child: const Text('ByLayer / CTB default'),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked < 0) {
      onApplyLayerOverride(layer, ov.copyWith(clearStroke: true));
    } else {
      onApplyLayerOverride(layer, ov.copyWith(strokeWidthPt: picked));
    }
  }

  Future<void> _pickLtScale(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
    ResolvedLineworkStyle resolved,
  ) async {
    var value = (ov.linetypeScale ?? 1.0).clamp(0.1, 20.0);
    final picked = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Linetype scale — $layer',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Slider(
                      value: value,
                      min: 0.1,
                      max: 20,
                      onChanged: (v) => setLocal(() => value = v),
                    ),
                    Text(value.toStringAsFixed(2)),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, -1.0),
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, value),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) return;
    if (picked < 0) {
      onApplyLayerOverride(layer, ov.copyWith(clearLinetypeScale: true));
    } else {
      onApplyLayerOverride(layer, ov.copyWith(linetypeScale: picked));
    }
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }
}

class _CellTap extends StatelessWidget {
  const _CellTap({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
