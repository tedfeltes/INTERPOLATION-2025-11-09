import 'package:flutter/material.dart';

import 'label_placement.dart';
import 'plot_options.dart';
import 'survey_point.dart';

/// Compact inspector shown when a stake point / label is selected.
class PointPropertiesPanel extends StatelessWidget {
  const PointPropertiesPanel({
    super.key,
    required this.point,
    required this.options,
    required this.onOptions,
    required this.onClose,
  });

  final SurveyPoint point;
  final PlotOptions options;
  final ValueChanged<PlotOptions> onOptions;
  final VoidCallback onClose;

  PointStyleOverride get _ov =>
      options.pointStyleOverrides[point.id] ?? const PointStyleOverride();

  PointLabelFormat get _format => _ov.labelFormat ?? options.labelFormat;

  int get _color {
    return _ov.colorArgb ??
        options.defaultPointColorArgb ??
        0xFFFF0000;
  }

  LabelDragState? get _drag => options.labelDrags[point.id];

  void _patchOverride(PointStyleOverride next) {
    final map = Map<String, PointStyleOverride>.from(options.pointStyleOverrides);
    if (next.isEmpty) {
      map.remove(point.id);
    } else {
      map[point.id] = next;
    }
    onOptions(options.copyWith(pointStyleOverrides: map));
  }

  void _patchDrag(LabelDragState? next) {
    final map = Map<String, LabelDragState>.from(options.labelDrags);
    if (next == null) {
      map.remove(point.id);
    } else {
      map[point.id] = next;
    }
    onOptions(options.copyWith(labelDrags: map));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'POINT ${point.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (_drag?.pinned == true || (_drag?.isDragged ?? false))
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'DRAGGED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.tertiary,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Text(
            'N ${point.northingText}  E ${point.eastingText}  Z ${point.elevText}'
            '${point.description.trim().isEmpty ? '' : '  ·  ${point.description.trim()}'}',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LABEL',
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
                  label: Text(f.label, style: const TextStyle(fontSize: 11)),
                  selected: _format == f,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) {
                    if (f == options.labelFormat) {
                      _patchOverride(_ov.copyWith(clearLabelFormat: true));
                    } else {
                      _patchOverride(_ov.copyWith(labelFormat: f));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'COLOR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in const [
                  0xFFFF0000,
                  0xFFE10600,
                  0xFF1A1A1A,
                  0xFF1565C0,
                  0xFF2E7D32,
                  0xFFF9A825,
                  0xFF6A1B9A,
                  0xFF757575,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _patchOverride(_ov.copyWith(colorArgb: c)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? Colors.white : Colors.white24,
                            width: _color == c ? 2.5 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      _patchOverride(_ov.copyWith(clearColor: true)),
                  child: const Text('Default', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey(
              'pt-label-${point.id}-${_format.name}-${_drag?.customText}',
            ),
            initialValue: _drag?.customText ??
                labelLinesFor(point, _format).join('\n'),
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Label text',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) {
              final prev = _drag ?? const LabelDragState();
              _patchDrag(prev.copyWith(customText: v, pinned: true));
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: () => _patchDrag(null),
                child: const Text('Reset drag', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () {
                  _patchOverride(const PointStyleOverride());
                  _patchDrag(null);
                },
                child: const Text('Reset all', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
