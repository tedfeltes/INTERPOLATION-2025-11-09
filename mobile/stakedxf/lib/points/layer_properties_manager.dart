import 'package:flutter/material.dart';

import 'color_picker_sheet.dart';
import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'linetype_catalog.dart';
import 'linework_style.dart';
import 'plot_ui_theme.dart';

/// Civil 3D–style Layer Properties Manager.
///
/// Each layer is one row: On · Lock · Color · LT · LW · LTS · Op · Name.
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
    this.lockedLayers = const {},
    this.onToggleLock,
    this.onSelectAll,
    this.entityCounts = const {},
  });

  final List<String> layers;
  final Map<String, DxfLayerStyle> layerStyles;
  final Set<String> selectedLayers;
  final Set<String> lockedLayers;
  final Map<String, LineworkStyleOverride> layerOverrides;
  final LinetypeCatalog catalog;
  final CtbPlotStyleTable ctb;
  final double globalLinetypeScale;
  final String? selectedLayer;
  final ValueChanged<String> onToggleLayer;
  final ValueChanged<String>? onToggleLock;
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
      color: PlotUi.muted,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: const Row(
        children: [
          SizedBox(width: 26, child: _H('On')),
          SizedBox(width: 26, child: _H('Lk')),
          SizedBox(width: 26, child: _H('C')),
          SizedBox(width: 40, child: _H('LT')),
          SizedBox(width: 32, child: _H('LW')),
          SizedBox(width: 32, child: _H('LTS')),
          SizedBox(width: 32, child: _H('Op')),
          Expanded(child: _H('Name')),
        ],
      ),
    );
  }

  Widget _layerRow(BuildContext context, ColorScheme cs, String layer) {
    final on = selectedLayers.contains(layer);
    final locked = lockedLayers.contains(layer);
    final resolved = _resolve(layer);
    final ov = layerOverrides[layer] ?? const LineworkStyleOverride();
    final selected = layer == selectedLayer;
    final count = entityCounts[layer];
    final ltAbbrev = _ltAbbrev(resolved.linetype.name);
    final lwLabel = resolved.strokeWidthPt.toStringAsFixed(1);
    final ltsLabel = resolved.linetypeScale.toStringAsFixed(1);
    final opLabel = '${(resolved.opacity * 100).round()}';

    return Material(
      color: selected
          ? PlotUi.selection.withValues(alpha: 0.10)
          : (on ? Colors.transparent : PlotUi.muted.withValues(alpha: 0.55)),
      child: InkWell(
        onTap: locked ? null : () => onSelectLayer(layer),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: on,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => onToggleLayer(layer),
                ),
              ),
              SizedBox(
                width: 26,
                height: 26,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tooltip: locked ? 'Unlock layer' : 'Lock layer',
                  onPressed: onToggleLock == null
                      ? null
                      : () => onToggleLock!(layer),
                  icon: Icon(
                    locked ? Icons.lock : Icons.lock_open,
                    size: 15,
                    color: locked ? PlotUi.selection : PlotUi.mutedFg,
                  ),
                ),
              ),
              SizedBox(
                width: 26,
                child: GestureDetector(
                  onTap: locked
                      ? null
                      : () => _pickColor(context, layer, ov, resolved),
                  child: Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: Color(resolved.colorArgb)
                          .withValues(alpha: resolved.opacity),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: PlotUi.border),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: _CellTap(
                  label: ltAbbrev,
                  onTap: locked
                      ? null
                      : () => _pickLinetype(context, layer, ov),
                ),
              ),
              SizedBox(
                width: 32,
                child: _CellTap(
                  label: lwLabel,
                  onTap: locked
                      ? null
                      : () => _pickLineweight(context, layer, ov),
                ),
              ),
              SizedBox(
                width: 32,
                child: _CellTap(
                  label: ltsLabel,
                  onTap: locked
                      ? null
                      : () => _pickLtScale(context, layer, ov, resolved),
                ),
              ),
              SizedBox(
                width: 32,
                child: _CellTap(
                  label: opLabel,
                  onTap: locked
                      ? null
                      : () => _pickOpacity(context, layer, ov, resolved),
                ),
              ),
              Expanded(
                child: Text(
                  count == null ? layer : '$layer  ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: on
                        ? PlotUi.fg
                        : PlotUi.fg.withValues(alpha: 0.4),
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
    final picked = await showPlotColorPicker(
      context: context,
      currentArgb: resolved.colorArgb,
      ctb: ctb,
      allowClear: true,
      title: 'Layer color — $layer',
    );
    if (picked == null) return;
    if (picked.argb == 0) {
      onApplyLayerOverride(layer, ov.copyWith(clearColor: true));
    } else {
      onApplyLayerOverride(layer, ov.copyWith(colorArgb: picked.argb));
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

  Future<void> _pickOpacity(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
    ResolvedLineworkStyle resolved,
  ) async {
    var value = (ov.opacity ?? resolved.opacity).clamp(0.05, 1.0);
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
                    Text('Opacity — $layer',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Slider(
                      value: value,
                      min: 0.05,
                      max: 1.0,
                      onChanged: (v) => setLocal(() => value = v),
                    ),
                    Text('${(value * 100).round()}%'),
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
      onApplyLayerOverride(layer, ov.copyWith(clearOpacity: true));
    } else {
      onApplyLayerOverride(layer, ov.copyWith(opacity: picked));
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
  const _CellTap({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
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
            color: enabled ? PlotUi.fg : PlotUi.mutedFg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
