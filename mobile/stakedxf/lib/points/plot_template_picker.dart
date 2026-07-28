import 'package:flutter/material.dart';

import 'plot_templates.dart';
import 'plot_ui_theme.dart';

/// Civil 3D–style sheet-template picker.
///
/// Replaces the two chained dropdowns (size + orientation) with a grid of
/// tap-selectable **cards** that match the slide-deck mockup. Each card
/// shows a small sheet icon in the correct portrait / landscape aspect,
/// the ANSI size label, its short × long inch callout, and an
/// orientation letter. The active template gets the accent (orange)
/// treatment. Cards can be tapped to switch templates without opening a
/// modal.
class PlotTemplatePicker extends StatelessWidget {
  const PlotTemplatePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final PlotTemplate selected;
  final ValueChanged<PlotTemplate> onSelected;
  final bool enabled;

  static List<PlotTemplate> _allTemplates() {
    final out = <PlotTemplate>[];
    for (final size in AnsiSheetSize.values) {
      for (final orient in SheetOrientation.values) {
        out.add(composePlotTemplate(size: size, orientation: orient));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final templates = _allTemplates();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns keep the cards readable on a tablet in portrait
        // (matches the slide-deck template mockup) while still fitting
        // an 8-template grid without scrolling.
        final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            mainAxisExtent: 68,
          ),
          itemCount: templates.length,
          itemBuilder: (context, i) {
            final t = templates[i];
            final active = t.size == selected.size &&
                t.orientation == selected.orientation;
            return _TemplateCard(
              template: t,
              active: active,
              onTap: enabled ? () => onSelected(t) : null,
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.active,
    required this.onTap,
  });

  final PlotTemplate template;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final orientLetter =
        template.orientation == SheetOrientation.landscape ? 'L' : 'P';
    final short = _fmt(template.size.shortIn);
    final long = _fmt(template.size.longIn);
    final orientCallout =
        template.orientation == SheetOrientation.landscape
            ? '$long × $short'
            : '$short × $long';
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? PlotUi.accentDim : PlotUi.card,
          border: Border.all(
            color: active ? PlotUi.accent : PlotUi.border,
            width: active ? 1.4 : 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              _SheetGlyph(template: template, active: active),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      template.size.label,
                      style: PlotUi.monoLabel.copyWith(
                        color: active ? PlotUi.accent : PlotUi.fg,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$orientCallout in  ·  $orientLetter',
                      style: PlotUi.mono.copyWith(
                        color: PlotUi.mutedFg,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Miniature sheet icon that respects portrait / landscape aspect ratio.
class _SheetGlyph extends StatelessWidget {
  const _SheetGlyph({required this.template, required this.active});

  final PlotTemplate template;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final portrait = template.orientation == SheetOrientation.portrait;
    final glyphSize = 34.0;
    final ratio = template.size.shortIn / template.size.longIn;
    final w = portrait ? glyphSize * ratio : glyphSize;
    final h = portrait ? glyphSize : glyphSize * ratio;
    return SizedBox(
      width: glyphSize,
      height: glyphSize,
      child: Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: PlotUi.muted,
            border: Border.all(
              color: active ? PlotUi.accent : PlotUi.mutedFg,
              width: 0.9,
            ),
          ),
          // Thin tick where the (optional) plot title sits by default so
          // users get a visual reminder of the full-bleed layout.
          child: Padding(
            padding: EdgeInsets.only(top: h * 0.16),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: w * 0.55,
                height: 1,
                color: PlotUi.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
