import 'package:flutter/material.dart';

import 'aci_palette.dart';
import 'ctb_plot_style.dart';
import 'plot_ui_theme.dart';

/// Result of a color pick: ARGB, optionally tagged with ACI.
class PickedColor {
  const PickedColor(this.argb, {this.aci});
  final int argb;
  final int? aci;
}

/// Professional color picker: CTB/ACI swatches + true-color grid.
Future<PickedColor?> showPlotColorPicker({
  required BuildContext context,
  required int currentArgb,
  CtbPlotStyleTable? ctb,
  bool allowClear = false,
  String title = 'Color',
}) {
  return showModalBottomSheet<PickedColor>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: PlotUi.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    // Cap sheet height so the plot preview stays visible above it.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.62,
    ),
    builder: (ctx) => _ColorPickerBody(
      currentArgb: currentArgb,
      ctb: ctb,
      allowClear: allowClear,
      title: title,
    ),
  );
}

class _ColorPickerBody extends StatefulWidget {
  const _ColorPickerBody({
    required this.currentArgb,
    required this.ctb,
    required this.allowClear,
    required this.title,
  });

  final int currentArgb;
  final CtbPlotStyleTable? ctb;
  final bool allowClear;
  final String title;

  @override
  State<_ColorPickerBody> createState() => _ColorPickerBodyState();
}

class _ColorPickerBodyState extends State<_ColorPickerBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late int _argb;
  double _hue = 0;
  double _sat = 0.85;
  double _val = 0.95;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _argb = widget.currentArgb | 0xFF000000;
    final hsv = HSVColor.fromColor(Color(_argb));
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fill the whole allowed sheet area — the outer constraints cap total
    // height at ~62% so the preview above the sheet stays visible.
    final height = MediaQuery.sizeOf(context).height * 0.6;
    final ctb = widget.ctb;
    final aciSwatches = buildAciSwatches(ctb);
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(_argb),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: PlotUi.border),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: PlotUi.fg,
              unselectedLabelColor: PlotUi.mutedFg,
              indicatorColor: PlotUi.accent,
              tabs: const [
                Tab(text: 'ACI / CTB'),
                Tab(text: 'True color'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _AciGrid(
                    swatches: aciSwatches,
                    selected: _argb,
                    onPick: (s) => Navigator.pop(
                      context,
                      PickedColor(s.argb, aci: s.aci),
                    ),
                  ),
                  _TrueColorPane(
                    hue: _hue,
                    sat: _sat,
                    val: _val,
                    argb: _argb,
                    onHue: (v) => setState(() {
                      _hue = v;
                      _argb = HSVColor.fromAHSV(1, _hue, _sat, _val)
                          .toColor()
                          .toARGB32();
                    }),
                    onSat: (v) => setState(() {
                      _sat = v;
                      _argb = HSVColor.fromAHSV(1, _hue, _sat, _val)
                          .toColor()
                          .toARGB32();
                    }),
                    onVal: (v) => setState(() {
                      _val = v;
                      _argb = HSVColor.fromAHSV(1, _hue, _sat, _val)
                          .toColor()
                          .toARGB32();
                    }),
                    onGridPick: (c) => setState(() {
                      _argb = c;
                      final hsv = HSVColor.fromColor(Color(c));
                      _hue = hsv.hue;
                      _sat = hsv.saturation;
                      _val = hsv.value;
                    }),
                    onApply: () => Navigator.pop(context, PickedColor(_argb)),
                  ),
                ],
              ),
            ),
            if (widget.allowClear)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const PickedColor(0), // sentinel clear handled by caller
                    ),
                    child: const Text('ByLayer / CTB default'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AciGrid extends StatelessWidget {
  const _AciGrid({
    required this.swatches,
    required this.selected,
    required this.onPick,
  });

  final List<AciSwatch> swatches;
  final int selected;
  final ValueChanged<AciSwatch> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: swatches.length,
      itemBuilder: (context, i) {
        final s = swatches[i];
        final sel = (selected & 0x00FFFFFF) == (s.argb & 0x00FFFFFF);
        return Tooltip(
          message: 'ACI ${s.aci}',
          child: InkWell(
            onTap: () => onPick(s),
            borderRadius: BorderRadius.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(s.argb),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: sel ? PlotUi.selection : PlotUi.border,
                  width: sel ? 2 : 0.8,
                ),
              ),
              child: sel
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _TrueColorPane extends StatelessWidget {
  const _TrueColorPane({
    required this.hue,
    required this.sat,
    required this.val,
    required this.argb,
    required this.onHue,
    required this.onSat,
    required this.onVal,
    required this.onGridPick,
    required this.onApply,
  });

  final double hue;
  final double sat;
  final double val;
  final int argb;
  final ValueChanged<double> onHue;
  final ValueChanged<double> onSat;
  final ValueChanged<double> onVal;
  final ValueChanged<int> onGridPick;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 160,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 12,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 12 * 8,
            itemBuilder: (context, i) {
              final col = i % 12;
              final row = i ~/ 12;
              final h = col * 30.0;
              final s = 0.35 + (row % 4) * 0.2;
              final v = row < 4 ? 0.95 : 0.55;
              final c = HSVColor.fromAHSV(1, h, s.clamp(0.2, 1.0), v)
                  .toColor()
                  .toARGB32();
              return GestureDetector(
                onTap: () => onGridPick(c),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(c),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text('Hue', style: PlotUi.tiny),
        Slider(value: hue, max: 360, onChanged: onHue),
        Text('Saturation', style: PlotUi.tiny),
        Slider(value: sat, onChanged: onSat),
        Text('Value', style: PlotUi.tiny),
        Slider(value: val, onChanged: onVal),
        const SizedBox(height: 4),
        FilledButton(onPressed: onApply, child: const Text('Use true color')),
      ],
    );
  }
}
