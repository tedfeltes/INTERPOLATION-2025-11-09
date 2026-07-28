import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aci_palette.dart';
import 'ctb_plot_style.dart';
import 'linetype_catalog.dart' show aciToArgb;
import 'plot_ui_theme.dart';

/// Result of a color pick: ARGB, optionally tagged with ACI.
class PickedColor {
  const PickedColor(this.argb, {this.aci});
  final int argb;
  final int? aci;
}

/// Professional color picker: CTB/ACI swatches + true-color HSV grid.
///
/// Mirrors the slide-deck "COLOR PICKER · ACI + CTB" mockup: a dense
/// 10-column palette of all 255 ACI colors up top, a live "current"
/// swatch + hex readout beside the title, and numeric input fields —
/// **ACI 1–255** on the palette tab and **#RRGGBB hex** on the
/// true-color tab — so surveyors can type the exact value they want
/// instead of hunting for it visually.
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
      maxHeight: MediaQuery.of(context).size.height * 0.68,
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
  int? _aci;
  double _hue = 0;
  double _sat = 0.85;
  double _val = 0.95;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _argb = widget.currentArgb | 0xFF000000;
    _aci = argbToAci(_argb, ctb: widget.ctb);
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

  void _selectAci(int aci) {
    final swatch = widget.ctb?.resolve(aci).colorArgb ?? aciToArgb(aci);
    setState(() {
      _argb = swatch | 0xFF000000;
      _aci = aci;
      final hsv = HSVColor.fromColor(Color(_argb));
      _hue = hsv.hue;
      _sat = hsv.saturation;
      _val = hsv.value;
    });
  }

  void _selectHex(int rgb) {
    setState(() {
      _argb = (rgb & 0x00FFFFFF) | 0xFF000000;
      _aci = argbToAci(_argb, ctb: widget.ctb);
      final hsv = HSVColor.fromColor(Color(_argb));
      _hue = hsv.hue;
      _sat = hsv.saturation;
      _val = hsv.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctb = widget.ctb;
    final aciSwatches = buildAciSwatchesByShade(ctb);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerBar(),
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
                _AciPane(
                  swatches: aciSwatches,
                  selected: _argb,
                  onPreviewAci: _selectAci,
                  onApply: () => Navigator.pop(
                    context,
                    PickedColor(_argb, aci: _aci),
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
                            .toARGB32() |
                        0xFF000000;
                    _aci = argbToAci(_argb, ctb: widget.ctb);
                  }),
                  onSat: (v) => setState(() {
                    _sat = v;
                    _argb = HSVColor.fromAHSV(1, _hue, _sat, _val)
                            .toColor()
                            .toARGB32() |
                        0xFF000000;
                    _aci = argbToAci(_argb, ctb: widget.ctb);
                  }),
                  onVal: (v) => setState(() {
                    _val = v;
                    _argb = HSVColor.fromAHSV(1, _hue, _sat, _val)
                            .toColor()
                            .toARGB32() |
                        0xFF000000;
                    _aci = argbToAci(_argb, ctb: widget.ctb);
                  }),
                  onGridPick: (c) => _selectHex(c),
                  onHexApply: (rgb) => _selectHex(rgb),
                  onApply: () => Navigator.pop(
                    context,
                    PickedColor(_argb, aci: _aci),
                  ),
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
    );
  }

  Widget _headerBar() {
    final hex = (_argb & 0x00FFFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(6, '0');
    final aciTag = _aci != null ? 'ACI $_aci' : 'True color';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$aciTag  ·  #$hex',
                  style: PlotUi.mono.copyWith(
                    fontSize: 11,
                    color: PlotUi.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(_argb),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: PlotUi.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _AciPane extends StatefulWidget {
  const _AciPane({
    required this.swatches,
    required this.selected,
    required this.onPreviewAci,
    required this.onApply,
  });

  final List<AciSwatch> swatches;
  final int selected;
  final ValueChanged<int> onPreviewAci;
  final VoidCallback onApply;

  @override
  State<_AciPane> createState() => _AciPaneState();
}

class _AciPaneState extends State<_AciPane> {
  final _aciCtrl = TextEditingController();

  @override
  void dispose() {
    _aciCtrl.dispose();
    super.dispose();
  }

  void _applyTypedAci() {
    final raw = _aciCtrl.text.trim();
    final n = int.tryParse(raw);
    if (n == null || n < 1 || n > 255) return;
    widget.onPreviewAci(n);
    _aciCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: widget.swatches.length,
            itemBuilder: (context, i) {
              final s = widget.swatches[i];
              final sel =
                  (widget.selected & 0x00FFFFFF) == (s.argb & 0x00FFFFFF);
              return Tooltip(
                message: 'ACI ${s.aci}',
                child: InkWell(
                  onTap: () => widget.onPreviewAci(s.aci),
                  onDoubleTap: () {
                    widget.onPreviewAci(s.aci);
                    widget.onApply();
                  },
                  borderRadius: BorderRadius.zero,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(s.argb),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: sel ? PlotUi.selection : PlotUi.border,
                        width: sel ? 2 : 0.5,
                      ),
                    ),
                    child: sel
                        ? const Icon(Icons.check,
                            size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aciCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onSubmitted: (_) => _applyTypedAci(),
                  decoration: const InputDecoration(
                    labelText: 'ACI number (1–255)',
                    isDense: true,
                    hintText: 'e.g. 34',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyTypedAci,
                child: const Text('Set'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: widget.onApply,
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrueColorPane extends StatefulWidget {
  const _TrueColorPane({
    required this.hue,
    required this.sat,
    required this.val,
    required this.argb,
    required this.onHue,
    required this.onSat,
    required this.onVal,
    required this.onGridPick,
    required this.onHexApply,
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
  final ValueChanged<int> onHexApply;
  final VoidCallback onApply;

  @override
  State<_TrueColorPane> createState() => _TrueColorPaneState();
}

class _TrueColorPaneState extends State<_TrueColorPane> {
  final _hexCtrl = TextEditingController();

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _applyTypedHex() {
    var raw = _hexCtrl.text.trim();
    if (raw.startsWith('#')) raw = raw.substring(1);
    if (raw.length == 3) {
      raw = raw.split('').map((c) => '$c$c').join();
    }
    if (raw.length != 6) return;
    final n = int.tryParse(raw, radix: 16);
    if (n == null) return;
    widget.onHexApply(n);
    _hexCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                onTap: () => widget.onGridPick(c),
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
        Slider(value: widget.hue, max: 360, onChanged: widget.onHue),
        Text('Saturation', style: PlotUi.tiny),
        Slider(value: widget.sat, onChanged: widget.onSat),
        Text('Value', style: PlotUi.tiny),
        Slider(value: widget.val, onChanged: widget.onVal),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hexCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onSubmitted: (_) => _applyTypedHex(),
                decoration: const InputDecoration(
                  labelText: 'Hex (#RRGGBB)',
                  isDense: true,
                  hintText: 'e.g. FFA800',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _applyTypedHex,
              child: const Text('Set'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: widget.onApply,
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }
}
