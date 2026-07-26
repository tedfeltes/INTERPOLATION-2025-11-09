import 'package:flutter/material.dart';

import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'linetype_catalog.dart';
import 'linework_style.dart';

/// Preset stroke weights in PDF/Flutter points.
const kLineweightPresets = <double>[0.35, 0.5, 0.7, 1.0, 1.4, 2.0, 2.8, 4.0];

/// Civil-ish color chips for quick linework recolor.
const kLineworkColorPresets = <int>[
  0xFF1A1A1A,
  0xFFE10600,
  0xFF1565C0,
  0xFF2E7D32,
  0xFFF9A825,
  0xFF6A1B9A,
  0xFF00838F,
  0xFF5D4037,
  0xFF757575,
  0xFFFF6F00,
];

/// Panel to edit lineweight / linetype / scale / color / opacity and
/// explode or remove nodes/segments on the selected linework.
class LineworkPropertiesPanel extends StatelessWidget {
  const LineworkPropertiesPanel({
    super.key,
    required this.catalog,
    required this.layerStyles,
    required this.selectedLayer,
    required this.selectedEntity,
    required this.layerOverride,
    required this.entityOverride,
    required this.globalLinetypeScale,
    required this.selectedNodeIndex,
    required this.selectedSegmentIndex,
    required this.onGlobalLinetypeScale,
    required this.onApplyLayerOverride,
    required this.onApplyEntityOverride,
    required this.onExplode,
    required this.onRemoveSegment,
    required this.onRemoveNode,
    required this.onDeleteEntity,
    required this.onClearSelection,
    this.ctbPlotStyle,
  });

  final LinetypeCatalog catalog;
  final Map<String, DxfLayerStyle> layerStyles;
  final String? selectedLayer;
  final LineworkEntity? selectedEntity;
  final LineworkStyleOverride? layerOverride;
  final LineworkStyleOverride? entityOverride;
  final double globalLinetypeScale;
  final int? selectedNodeIndex;
  final int? selectedSegmentIndex;
  final ValueChanged<double> onGlobalLinetypeScale;
  final ValueChanged<LineworkStyleOverride> onApplyLayerOverride;
  final ValueChanged<LineworkStyleOverride> onApplyEntityOverride;
  final VoidCallback? onExplode;
  final VoidCallback? onRemoveSegment;
  final VoidCallback? onRemoveNode;
  final VoidCallback? onDeleteEntity;
  final VoidCallback? onClearSelection;
  final CtbPlotStyleTable? ctbPlotStyle;

  bool get _editingEntity => selectedEntity != null;

  LineworkStyleOverride get _active =>
      _editingEntity
          ? (entityOverride ?? const LineworkStyleOverride())
          : (layerOverride ?? const LineworkStyleOverride());

  ResolvedLineworkStyle? get _resolved {
    final ent = selectedEntity;
    if (ent == null && selectedLayer == null) return null;
    final probe = ent ??
        LineworkEntity(
          id: '_layer',
          layer: selectedLayer!,
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
      layerOverrides: {
        if (selectedLayer != null && layerOverride != null)
          selectedLayer!: layerOverride!,
      },
      entityOverrides: {
        if (ent != null && entityOverride != null) ent.id: entityOverride!,
      },
      globalLinetypeScale: globalLinetypeScale,
      ctb: ctbPlotStyle,
    );
  }

  void _patch(LineworkStyleOverride next) {
    if (_editingEntity) {
      onApplyEntityOverride(next);
    } else {
      onApplyLayerOverride(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = _resolved;
    final target = _editingEntity
        ? 'Entity ${selectedEntity!.type} · ${selectedEntity!.layer}'
        : (selectedLayer == null
            ? 'Select a layer or tap linework on the preview'
            : 'Layer $selectedLayer');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                target,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (selectedEntity != null || selectedLayer != null)
              TextButton(
                onPressed: onClearSelection,
                child: const Text('Clear'),
              ),
          ],
        ),
        Text(
          'Change lineweight, linetype, linescale, color, and opacity. '
          'Explode polylines into segments; select green segment nodes or '
          'blue vertices to remove unwanted geometry.',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.65),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Global LT scale', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: globalLinetypeScale.clamp(0.25, 8.0),
                min: 0.25,
                max: 8.0,
                divisions: 31,
                label: globalLinetypeScale.toStringAsFixed(2),
                onChanged: onGlobalLinetypeScale,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                globalLinetypeScale.toStringAsFixed(2),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        if (resolved != null) ...[
          const SizedBox(height: 4),
          Text('Color', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in kLineworkColorPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _patch(_active.copyWith(colorArgb: c)),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (resolved.colorArgb & 0x00FFFFFF) ==
                                    (c & 0x00FFFFFF)
                                ? Colors.white
                                : Colors.white24,
                            width: (resolved.colorArgb & 0x00FFFFFF) ==
                                    (c & 0x00FFFFFF)
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
              const Text('Opacity', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: resolved.opacity,
                  min: 0.15,
                  max: 1.0,
                  divisions: 17,
                  onChanged: (v) => _patch(_active.copyWith(opacity: v)),
                ),
              ),
              Text('${(resolved.opacity * 100).round()}%'),
            ],
          ),
          Row(
            children: [
              const Text('Lineweight', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: resolved.strokeWidthPt.clamp(0.35, 4.0),
                  min: 0.35,
                  max: 4.0,
                  divisions: 15,
                  onChanged: (v) =>
                      _patch(_active.copyWith(strokeWidthPt: v)),
                ),
              ),
              Text('${resolved.strokeWidthPt.toStringAsFixed(2)} pt'),
            ],
          ),
          Builder(
            builder: (context) {
              final names = [
                for (final lt in catalog.linetypes) lt.name,
              ];
              final current = catalog.resolve(resolved.linetype.name).name;
              final value = names.contains(current)
                  ? current
                  : (names.isEmpty ? null : names.first);
              return DropdownButtonFormField<String>(
                value: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Linetype',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final lt in catalog.linetypes)
                    DropdownMenuItem(
                      value: lt.name,
                      child: Text(
                        lt.description.isEmpty
                            ? lt.name
                            : '${lt.name} — ${lt.description}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _patch(_active.copyWith(linetypeName: v));
                },
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Linescale', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: (_active.linetypeScale ??
                          selectedEntity?.linetypeScale ??
                          1.0)
                      .clamp(0.25, 8.0),
                  min: 0.25,
                  max: 8.0,
                  divisions: 31,
                  onChanged: (v) =>
                      _patch(_active.copyWith(linetypeScale: v)),
                ),
              ),
              Text(
                (_active.linetypeScale ??
                        selectedEntity?.linetypeScale ??
                        1.0)
                    .toStringAsFixed(2),
              ),
            ],
          ),
          // Mini pattern preview
          Container(
            height: 28,
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EE),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: CustomPaint(
              painter: _LinetypePreviewPainter(resolved),
              size: const Size(double.infinity, 28),
            ),
          ),
        ],
        if (selectedEntity != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: onExplode,
                icon: const Icon(Icons.call_split, size: 18),
                label: const Text('Explode'),
              ),
              OutlinedButton.icon(
                onPressed: selectedSegmentIndex == null ? null : onRemoveSegment,
                icon: const Icon(Icons.content_cut, size: 18),
                label: Text(
                  selectedSegmentIndex == null
                      ? 'Remove segment'
                      : 'Remove seg ${selectedSegmentIndex! + 1}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: selectedNodeIndex == null ? null : onRemoveNode,
                icon: const Icon(Icons.highlight_off, size: 18),
                label: Text(
                  selectedNodeIndex == null
                      ? 'Remove node'
                      : 'Remove node ${selectedNodeIndex! + 1}',
                ),
              ),
              TextButton.icon(
                onPressed: onDeleteEntity,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LinetypePreviewPainter extends CustomPainter {
  _LinetypePreviewPainter(this.style);
  final ResolvedLineworkStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = Color(style.colorWithOpacity)
      ..strokeWidth = style.strokeWidthPt.clamp(1.0, 4.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final dash = style.dashPatternPoints();
    if (dash.isEmpty) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
      return;
    }
    var x = 8.0;
    var drawing = true;
    var i = 0;
    while (x < size.width - 8) {
      final len = dash[i % dash.length].clamp(1.0, 40.0);
      final next = (x + len).clamp(8.0, size.width - 8);
      if (drawing) {
        canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      }
      x = next;
      drawing = !drawing;
      i++;
      if (next >= size.width - 8) break;
    }
  }

  @override
  bool shouldRepaint(covariant _LinetypePreviewPainter old) =>
      old.style != style;
}
