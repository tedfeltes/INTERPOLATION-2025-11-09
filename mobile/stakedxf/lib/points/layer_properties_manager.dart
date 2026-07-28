import 'package:flutter/material.dart';

import 'aci_palette.dart';
import 'color_picker_sheet.dart';
import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'linetype_catalog.dart';
import 'linework_style.dart';
import 'plot_ui_theme.dart';

/// Civil 3D–style **Layer Properties Manager**.
///
/// Header toolbar → sortable column strip → sticky Name column with
/// horizontally scrolling data grid, styled with the StakeDXF instrument
/// palette (safety-orange current-layer bar, zebra rows, hairline dividers).
///
/// Data columns (mirroring Civil 3D):
///  * `On`       — light-bulb toggle (draws layer)
///  * `Frz`      — freeze marker (alias for Off in this build)
///  * `Lk`       — padlock (prevents accidental selection)
///  * `Color`    — layer color swatch (ACI + True color picker)
///  * `Linetype` — CONTINUOUS / DASHED / …
///  * `LW`       — lineweight in points
///  * `Trans`    — transparency %
///  * `LTS`      — per-layer linetype scale
///
/// The `Name` column stays fixed on the left; everything to the right
/// scrolls horizontally exactly like the AutoCAD/Civil 3D grid.
class LayerPropertiesManager extends StatefulWidget {
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

  @override
  State<LayerPropertiesManager> createState() => _LayerPropertiesManagerState();
}

enum _LpmFilter { all, on, off, locked, overridden }

enum _LpmSort { name, count, color, linetype, weight, transparency }

class _LayerPropertiesManagerState extends State<LayerPropertiesManager> {
  final _search = TextEditingController();
  final _scrollCtrl = ScrollController();
  _LpmFilter _filter = _LpmFilter.all;
  _LpmSort _sort = _LpmSort.name;
  bool _sortAsc = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text.trim().toLowerCase();
      if (q != _query) {
        setState(() => _query = q);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

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
      catalog: widget.catalog,
      layerStyles: widget.layerStyles,
      layerOverrides: widget.layerOverrides,
      globalLinetypeScale: widget.globalLinetypeScale,
      ctb: widget.ctb,
    );
  }

  List<String> _visibleLayers() {
    final layers = widget.layers.where((l) {
      if (_query.isNotEmpty && !l.toLowerCase().contains(_query)) return false;
      switch (_filter) {
        case _LpmFilter.all:
          return true;
        case _LpmFilter.on:
          return widget.selectedLayers.contains(l);
        case _LpmFilter.off:
          return !widget.selectedLayers.contains(l);
        case _LpmFilter.locked:
          return widget.lockedLayers.contains(l);
        case _LpmFilter.overridden:
          return widget.layerOverrides.containsKey(l);
      }
    }).toList();

    layers.sort((a, b) {
      final ra = _resolve(a);
      final rb = _resolve(b);
      int cmp;
      switch (_sort) {
        case _LpmSort.name:
          cmp = a.toLowerCase().compareTo(b.toLowerCase());
          break;
        case _LpmSort.count:
          cmp = (widget.entityCounts[a] ?? 0)
              .compareTo(widget.entityCounts[b] ?? 0);
          break;
        case _LpmSort.color:
          cmp = ra.colorArgb.compareTo(rb.colorArgb);
          break;
        case _LpmSort.linetype:
          cmp = ra.linetype.name.compareTo(rb.linetype.name);
          break;
        case _LpmSort.weight:
          cmp = ra.strokeWidthPt.compareTo(rb.strokeWidthPt);
          break;
        case _LpmSort.transparency:
          cmp = ra.opacity.compareTo(rb.opacity);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return layers;
  }

  @override
  Widget build(BuildContext context) {
    final layers = _visibleLayers();
    final onCount = widget.layers.where(widget.selectedLayers.contains).length;
    final total = widget.layers.length;

    return Container(
      decoration: BoxDecoration(
        color: PlotUi.card,
        border: Border.all(color: PlotUi.border),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titleBar(onCount, total),
          const Divider(height: 1, color: PlotUi.border),
          _toolbar(),
          const Divider(height: 1, color: PlotUi.border),
          _filterBar(),
          const Divider(height: 1, color: PlotUi.border),
          _searchBar(),
          const Divider(height: 1, color: PlotUi.border),
          _grid(layers),
          const Divider(height: 1, color: PlotUi.border),
          _footer(),
        ],
      ),
    );
  }

  Widget _titleBar(int on, int total) {
    return Container(
      color: PlotUi.rail,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: PlotUi.accent),
          const SizedBox(width: 8),
          Text(
            'LAYER PROPERTIES MANAGER',
            style: PlotUi.monoLabel.copyWith(color: PlotUi.fg, fontSize: 11),
          ),
          const Spacer(),
          Text(
            '$on / $total ON',
            style: PlotUi.mono.copyWith(fontSize: 10.5, color: PlotUi.mutedFg),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final buttons = <Widget>[
      _ToolButton(
        tooltip: 'Turn all layers on',
        icon: Icons.lightbulb_outline,
        onPressed: () => _bulkSetOn(true),
      ),
      _ToolButton(
        tooltip: 'Turn all layers off',
        icon: Icons.lightbulb,
        offVariant: true,
        onPressed: () => _bulkSetOn(false),
      ),
      _ToolButton(
        tooltip: 'Invert on/off',
        icon: Icons.swap_horiz,
        onPressed: _invertOn,
      ),
      _ToolDivider(),
      _ToolButton(
        tooltip: 'Lock all',
        icon: Icons.lock,
        onPressed: widget.onToggleLock == null
            ? null
            : () => _bulkSetLock(true),
      ),
      _ToolButton(
        tooltip: 'Unlock all',
        icon: Icons.lock_open,
        onPressed: widget.onToggleLock == null
            ? null
            : () => _bulkSetLock(false),
      ),
      _ToolDivider(),
      _ToolButton(
        tooltip: 'Reset selected layer overrides',
        icon: Icons.replay,
        onPressed: widget.selectedLayer == null
            ? null
            : () => _resetLayerOverrides(widget.selectedLayer!),
      ),
      _ToolButton(
        tooltip: 'Reset ALL overrides',
        icon: Icons.restart_alt,
        onPressed: widget.layerOverrides.isEmpty ? null : _resetAllOverrides,
      ),
      _ToolDivider(),
      _ToolButton(
        tooltip: 'Refresh sort',
        icon: Icons.refresh,
        onPressed: () => setState(() {}),
      ),
    ];

    return Container(
      color: PlotUi.elevated,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      height: 34,
      child: Row(children: buttons),
    );
  }

  Widget _filterBar() {
    Widget chip(String label, _LpmFilter value) {
      final active = _filter == value;
      return GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: active ? PlotUi.accentDim : PlotUi.muted,
            border: Border.all(
              color: active ? PlotUi.accent : PlotUi.border,
              width: active ? 1.2 : 1,
            ),
          ),
          child: Text(
            label,
            style: PlotUi.mono.copyWith(
              fontSize: 10.5,
              color: active ? PlotUi.accent : PlotUi.dim,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      );
    }

    return Container(
      color: PlotUi.card,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          Text('FILTER',
              style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip('ALL', _LpmFilter.all),
                  chip('ON', _LpmFilter.on),
                  chip('OFF', _LpmFilter.off),
                  chip('LOCKED', _LpmFilter.locked),
                  chip('OVERRIDDEN', _LpmFilter.overridden),
                ],
              ),
            ),
          ),
          if (widget.onSelectAll != null)
            InkWell(
              onTap: widget.onSelectAll,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'ALL / NONE',
                  style: PlotUi.monoLabel.copyWith(color: PlotUi.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: PlotUi.card,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.search, size: 15, color: PlotUi.mutedFg),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _search,
              style: PlotUi.mono.copyWith(color: PlotUi.fg, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                hintText: 'Filter layers…',
                hintStyle: PlotUi.mono.copyWith(color: PlotUi.mutedFg),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 22, height: 22),
              icon: const Icon(Icons.close, color: PlotUi.mutedFg),
              onPressed: () => _search.clear(),
            ),
        ],
      ),
    );
  }

  // Column widths in the scrolling data strip.
  static const double _colOn = 40;
  static const double _colFrz = 40;
  static const double _colLock = 40;
  // Wider than the other cells so the ACI number ("ACI 34") / true-color
  // hex ("#FFA800") text fits beside the swatch, Civil 3D style.
  static const double _colColor = 96;
  static const double _colLinetype = 82;
  static const double _colWeight = 46;
  static const double _colTrans = 46;
  static const double _colLts = 46;
  static const double _nameColWidth = 150;

  double get _dataStripWidth =>
      _colOn +
      _colFrz +
      _colLock +
      _colColor +
      _colLinetype +
      _colWeight +
      _colTrans +
      _colLts;

  Widget _grid(List<String> layers) {
    if (layers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          _query.isEmpty ? 'NO LAYERS MATCH FILTER' : 'NO LAYERS MATCH “$_query”',
          style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg),
        ),
      );
    }
    // Match the SizedBox height to the *actual* row count (header + rows +
    // a small pad). Previously we hard-capped the height at
    // ``_rowHeight * 13`` regardless of layer count — but the Column below
    // still rendered all N rows, so with a large DXF (107 layers in the
    // OLDE_HIGHLANDER field bug report) the overflow painted on top of the
    // GLOBAL LTS footer *and* the next sticky sections (OBJECTS / TITLE /
    // TEXT / POINTS). Sizing to the true grid height lets the outer
    // CustomScrollView on the Export Points screen scroll cleanly through
    // every layer, then land on the GLOBAL LTS slider, then the next
    // section — no overlap, no ghosted text behind the slider.
    final gridHeight = _rowHeight * (layers.length + 1) + 8;
    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nameColumn(layers),
          Container(width: 1, color: PlotUi.borderStrong),
          Expanded(
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _dataStripWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dataHeaderRow(),
                      const Divider(height: 1, color: PlotUi.border),
                      for (var i = 0; i < layers.length; i++)
                        _dataRow(layers[i], i),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _rowHeight = 30;

  Widget _nameColumn(List<String> layers) {
    return SizedBox(
      width: _nameColWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nameHeader(),
          const Divider(height: 1, color: PlotUi.border),
          for (var i = 0; i < layers.length; i++) _nameRow(layers[i], i),
        ],
      ),
    );
  }

  Widget _nameHeader() {
    return _headerCell(
      height: _rowHeight,
      onTap: () => _toggleSort(_LpmSort.name),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(
            _sort == _LpmSort.name
                ? (_sortAsc ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                : Icons.remove,
            size: 14,
            color: _sort == _LpmSort.name ? PlotUi.accent : PlotUi.mutedFg,
          ),
          Text(
            'NAME',
            style: PlotUi.monoLabel.copyWith(
              color: _sort == _LpmSort.name ? PlotUi.fg : PlotUi.dim,
              fontSize: 10.5,
            ),
          ),
          const Spacer(),
          Text(
            'ENT',
            style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _nameRow(String layer, int idx) {
    final selected = layer == widget.selectedLayer;
    final on = widget.selectedLayers.contains(layer);
    final locked = widget.lockedLayers.contains(layer);
    final zebra = idx.isOdd ? PlotUi.muted.withValues(alpha: 0.5) : PlotUi.card;
    final overridden = widget.layerOverrides.containsKey(layer);
    final count = widget.entityCounts[layer];

    return InkWell(
      onTap: locked ? null : () => widget.onSelectLayer(layer),
      child: Container(
        height: _rowHeight,
        color: selected ? PlotUi.accentDim : zebra,
        child: Row(
          children: [
            SizedBox(
              width: 4,
              child: selected
                  ? Container(color: PlotUi.accent)
                  : (overridden
                      ? Container(color: PlotUi.warn.withValues(alpha: 0.8))
                      : const SizedBox()),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 18,
              child: locked
                  ? const Icon(Icons.lock, size: 12, color: PlotUi.mutedFg)
                  : (selected
                      ? const Icon(Icons.play_arrow,
                          size: 12, color: PlotUi.accent)
                      : const SizedBox()),
            ),
            Expanded(
              child: Text(
                layer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: on
                      ? (selected ? PlotUi.fg : PlotUi.dim)
                      : PlotUi.mutedFg,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '$count',
                  style: PlotUi.mono.copyWith(
                    fontSize: 10.5,
                    color: PlotUi.mutedFg,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dataHeaderRow() {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          _colHeader('On', _colOn,
              icon: Icons.lightbulb_outline, sort: null),
          _colHeader('Frz', _colFrz,
              icon: Icons.ac_unit, sort: null),
          _colHeader('Lk', _colLock, icon: Icons.lock_outline, sort: null),
          _colHeader('Color', _colColor, sort: _LpmSort.color),
          _colHeader('Linetype', _colLinetype, sort: _LpmSort.linetype),
          _colHeader('LW', _colWeight, sort: _LpmSort.weight),
          _colHeader('Trans', _colTrans, sort: _LpmSort.transparency),
          _colHeader('LTS', _colLts, sort: null),
        ],
      ),
    );
  }

  Widget _colHeader(
    String label,
    double width, {
    IconData? icon,
    _LpmSort? sort,
  }) {
    final active = sort != null && _sort == sort;
    return _headerCell(
      width: width,
      height: _rowHeight,
      onTap: sort == null ? null : () => _toggleSort(sort),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: active ? PlotUi.accent : PlotUi.dim),
            const SizedBox(width: 3),
          ],
          Text(
            label.toUpperCase(),
            style: PlotUi.monoLabel.copyWith(
              fontSize: 10,
              color: active ? PlotUi.accent : PlotUi.dim,
            ),
          ),
          if (active)
            Icon(
              _sortAsc ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: 12,
              color: PlotUi.accent,
            ),
        ],
      ),
    );
  }

  Widget _headerCell({
    double? width,
    required double height,
    VoidCallback? onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: PlotUi.elevated,
          border: Border(
            right: BorderSide(color: PlotUi.border, width: 1),
            bottom: BorderSide(color: PlotUi.border, width: 1),
          ),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _dataRow(String layer, int idx) {
    final on = widget.selectedLayers.contains(layer);
    final locked = widget.lockedLayers.contains(layer);
    final selected = layer == widget.selectedLayer;
    final resolved = _resolve(layer);
    final ov = widget.layerOverrides[layer] ?? const LineworkStyleOverride();
    final zebra = idx.isOdd ? PlotUi.muted.withValues(alpha: 0.5) : PlotUi.card;
    final bg = selected ? PlotUi.accentDim : zebra;

    return Container(
      height: _rowHeight,
      color: bg,
      child: Row(
        children: [
          _dataCell(
            _colOn,
            onTap: () => widget.onToggleLayer(layer),
            child: _StateIcon(
              on: on,
              onIcon: Icons.lightbulb,
              offIcon: Icons.lightbulb_outline,
              onColor: PlotUi.warn,
              offColor: PlotUi.mutedFg,
            ),
          ),
          _dataCell(
            _colFrz,
            onTap: () => widget.onToggleLayer(layer),
            child: _StateIcon(
              on: !on,
              onIcon: Icons.ac_unit,
              offIcon: Icons.wb_sunny_outlined,
              onColor: const Color(0xFF6FC5FF),
              offColor: PlotUi.mutedFg,
            ),
          ),
          _dataCell(
            _colLock,
            onTap: widget.onToggleLock == null
                ? null
                : () => widget.onToggleLock!(layer),
            child: _StateIcon(
              on: locked,
              onIcon: Icons.lock,
              offIcon: Icons.lock_open,
              onColor: PlotUi.accent,
              offColor: PlotUi.mutedFg,
            ),
          ),
          _dataCell(
            _colColor,
            onTap: locked
                ? null
                : () => _pickColor(context, layer, ov, resolved),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(resolved.colorArgb).withValues(
                        alpha: resolved.opacity.clamp(0.05, 1.0),
                      ),
                      border: Border.all(color: PlotUi.borderStrong),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      // Civil 3D–style read-out: "ACI 34" for palette
                      // matches, "#FFA800" hex for true-color overrides.
                      aciLabelFor(resolved.colorArgb, ctb: widget.ctb),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlotUi.mono.copyWith(
                        fontSize: 9.5,
                        color: on ? PlotUi.fg : PlotUi.mutedFg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _dataCell(
            _colLinetype,
            onTap: locked ? null : () => _pickLinetype(context, layer, ov),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 30,
                  child: CustomPaint(
                    painter: _LinetypePreview(resolved),
                    size: const Size(30, 8),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _ltAbbrev(resolved.linetype.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlotUi.mono.copyWith(
                      fontSize: 10.5,
                      color: on ? PlotUi.fg : PlotUi.mutedFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _dataCell(
            _colWeight,
            onTap: locked
                ? null
                : () => _pickLineweight(context, layer, ov),
            child: Text(
              resolved.strokeWidthPt.toStringAsFixed(2),
              style: PlotUi.mono.copyWith(
                fontSize: 10.5,
                color: on ? PlotUi.fg : PlotUi.mutedFg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _dataCell(
            _colTrans,
            onTap: locked
                ? null
                : () => _pickOpacity(context, layer, ov, resolved),
            child: Text(
              '${(100 - resolved.opacity * 100).round()}',
              style: PlotUi.mono.copyWith(
                fontSize: 10.5,
                color: on ? PlotUi.fg : PlotUi.mutedFg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _dataCell(
            _colLts,
            onTap: locked
                ? null
                : () => _pickLtScale(context, layer, ov, resolved),
            child: Text(
              resolved.linetypeScale.toStringAsFixed(1),
              style: PlotUi.mono.copyWith(
                fontSize: 10.5,
                color: on ? PlotUi.fg : PlotUi.mutedFg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCell(double width,
      {required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: _rowHeight,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: PlotUi.border, width: 1),
            bottom: BorderSide(color: PlotUi.border, width: 1),
          ),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _footer() {
    return Container(
      color: PlotUi.rail,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('GLOBAL  LTS',
                  style: PlotUi.monoLabel.copyWith(color: PlotUi.mutedFg)),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: widget.globalLinetypeScale.clamp(0.1, 10.0),
                    min: 0.1,
                    max: 10.0,
                    onChanged: widget.onGlobalLinetypeScale,
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  widget.globalLinetypeScale.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: PlotUi.mono.copyWith(
                    fontSize: 11,
                    color: PlotUi.fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a linework segment on the preview to select its layer. '
            'Column headers with arrows are sortable — Civil 3D style. '
            'Yellow bar = per-layer override applied.',
            style: PlotUi.tiny.copyWith(color: PlotUi.mutedFg, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  void _toggleSort(_LpmSort s) {
    setState(() {
      if (_sort == s) {
        _sortAsc = !_sortAsc;
      } else {
        _sort = s;
        _sortAsc = true;
      }
    });
  }

  void _bulkSetOn(bool value) {
    for (final l in widget.layers) {
      final currentlyOn = widget.selectedLayers.contains(l);
      if (currentlyOn != value) {
        widget.onToggleLayer(l);
      }
    }
  }

  void _invertOn() {
    for (final l in widget.layers) {
      widget.onToggleLayer(l);
    }
  }

  void _bulkSetLock(bool value) {
    final toggle = widget.onToggleLock;
    if (toggle == null) return;
    for (final l in widget.layers) {
      final locked = widget.lockedLayers.contains(l);
      if (locked != value) toggle(l);
    }
  }

  void _resetAllOverrides() {
    for (final l in widget.layerOverrides.keys.toList()) {
      widget.onApplyLayerOverride(l, const LineworkStyleOverride());
    }
  }

  void _resetLayerOverrides(String layer) {
    widget.onApplyLayerOverride(layer, const LineworkStyleOverride());
  }

  String _ltAbbrev(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'CONT';
    if (n.toUpperCase().startsWith('CONT')) return 'CONT';
    if (n.length <= 6) return n.toUpperCase();
    return '${n.substring(0, 5).toUpperCase()}…';
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
      ctb: widget.ctb,
      allowClear: true,
      title: 'Layer color — $layer',
    );
    if (picked == null) return;
    if (picked.argb == 0) {
      widget.onApplyLayerOverride(layer, ov.copyWith(clearColor: true));
    } else {
      widget.onApplyLayerOverride(layer, ov.copyWith(colorArgb: picked.argb));
    }
  }

  Future<void> _pickLinetype(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
  ) async {
    final names = widget.catalog.names;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: PlotUi.card,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Row(
                    children: [
                      Container(width: 3, height: 14, color: PlotUi.accent),
                      const SizedBox(width: 8),
                      Text(
                        'LINETYPE — ${layer.toUpperCase()}',
                        style: PlotUi.monoLabel.copyWith(color: PlotUi.fg),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: PlotUi.border),
                Expanded(
                  child: ListView.separated(
                    itemCount: names.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: PlotUi.border),
                    itemBuilder: (_, i) {
                      final n = names[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          n,
                          style: PlotUi.mono.copyWith(color: PlotUi.fg),
                        ),
                        onTap: () => Navigator.pop(ctx, n),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: PlotUi.border),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('BYLAYER DEFAULT'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked.isEmpty) {
      widget.onApplyLayerOverride(layer, ov.copyWith(clearLinetype: true));
    } else {
      widget.onApplyLayerOverride(layer, ov.copyWith(linetypeName: picked));
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
      backgroundColor: PlotUi.card,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Row(
                  children: [
                    Container(width: 3, height: 14, color: PlotUi.accent),
                    const SizedBox(width: 8),
                    Text(
                      'LINEWEIGHT (pt) — ${layer.toUpperCase()}',
                      style: PlotUi.monoLabel.copyWith(color: PlotUi.fg),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: PlotUi.border),
              for (final w in weights)
                ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 40,
                    height: 12,
                    child: CustomPaint(
                      painter: _WeightPreview(w),
                    ),
                  ),
                  title: Text(
                    w.toStringAsFixed(2),
                    style: PlotUi.mono.copyWith(color: PlotUi.fg),
                  ),
                  onTap: () => Navigator.pop(ctx, w),
                ),
              const Divider(height: 1, color: PlotUi.border),
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, -1.0),
                    child: const Text('BYLAYER / CTB DEFAULT'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    if (picked < 0) {
      widget.onApplyLayerOverride(layer, ov.copyWith(clearStroke: true));
    } else {
      widget.onApplyLayerOverride(layer, ov.copyWith(strokeWidthPt: picked));
    }
  }

  Future<void> _pickOpacity(
    BuildContext context,
    String layer,
    LineworkStyleOverride ov,
    ResolvedLineworkStyle resolved,
  ) async {
    var value = (ov.opacity ?? resolved.opacity).clamp(0.0, 1.0);
    final picked = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      backgroundColor: PlotUi.card,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 14, color: PlotUi.accent),
                        const SizedBox(width: 8),
                        Text(
                          'TRANSPARENCY — ${layer.toUpperCase()}',
                          style: PlotUi.monoLabel.copyWith(color: PlotUi.fg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Live swatch so fade is obvious even with selection chrome.
                    Center(
                      child: Container(
                        width: 72,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Color(resolved.colorArgb | 0xFF000000)
                              .withValues(alpha: value),
                          border: Border.all(color: PlotUi.border),
                        ),
                      ),
                    ),
                    Slider(
                      value: value,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        setLocal(() => value = v);
                        widget.onApplyLayerOverride(
                            layer, ov.copyWith(opacity: v));
                      },
                    ),
                    Text(
                      'OPACITY  ${(value * 100).round()}%   ·   '
                      'TRANS  ${(100 - value * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: PlotUi.mono.copyWith(color: PlotUi.dim),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, -1.0),
                          child: const Text('RESET'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, value),
                          child: const Text('APPLY'),
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
      widget.onApplyLayerOverride(layer, ov.copyWith(clearOpacity: true));
    } else {
      widget.onApplyLayerOverride(layer, ov.copyWith(opacity: picked));
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
      backgroundColor: PlotUi.card,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 14, color: PlotUi.accent),
                        const SizedBox(width: 8),
                        Text(
                          'LINETYPE SCALE — ${layer.toUpperCase()}',
                          style: PlotUi.monoLabel.copyWith(color: PlotUi.fg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: value,
                      min: 0.1,
                      max: 20,
                      onChanged: (v) => setLocal(() => value = v),
                    ),
                    Text(
                      value.toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: PlotUi.mono.copyWith(color: PlotUi.dim),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, -1.0),
                          child: const Text('RESET'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, value),
                          child: const Text('APPLY'),
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
      widget.onApplyLayerOverride(layer, ov.copyWith(clearLinetypeScale: true));
    } else {
      widget.onApplyLayerOverride(layer, ov.copyWith(linetypeScale: picked));
    }
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({
    required this.on,
    required this.onIcon,
    required this.offIcon,
    required this.onColor,
    required this.offColor,
  });
  final bool on;
  final IconData onIcon;
  final IconData offIcon;
  final Color onColor;
  final Color offColor;

  @override
  Widget build(BuildContext context) {
    return Icon(
      on ? onIcon : offIcon,
      size: 14,
      color: on ? onColor : offColor,
    );
  }
}

class _LinetypePreview extends CustomPainter {
  _LinetypePreview(this.style);
  final ResolvedLineworkStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(style.colorArgb).withValues(alpha: 0.9)
      ..strokeWidth = (style.strokeWidthPt.clamp(0.4, 2.0)).toDouble()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    final pattern = _patternForName(style.linetype.name);
    if (pattern.isEmpty) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    double x = 0;
    var draw = true;
    var idx = 0;
    while (x < size.width) {
      final seg = pattern[idx % pattern.length];
      final next = (x + seg).clamp(0.0, size.width);
      if (draw) {
        canvas.drawLine(Offset(x, y), Offset(next.toDouble(), y), paint);
      }
      x = next.toDouble();
      draw = !draw;
      idx++;
    }
  }

  List<double> _patternForName(String name) {
    final n = name.toUpperCase();
    if (n.contains('DASHDOT') || n.contains('DIVIDE')) {
      return const [5, 2, 1, 2];
    }
    if (n.contains('DASH')) return const [4, 2];
    if (n.contains('HIDDEN')) return const [3, 2];
    if (n.contains('CENTER')) return const [6, 2, 1, 2];
    if (n.contains('PHANTOM')) return const [7, 2, 1, 2, 1, 2];
    if (n.contains('DOT')) return const [1, 2];
    if (n.contains('BORDER')) return const [5, 2, 5, 2, 1, 2];
    return const [];
  }

  @override
  bool shouldRepaint(covariant _LinetypePreview old) =>
      old.style.linetype.name != style.linetype.name ||
      old.style.colorArgb != style.colorArgb ||
      old.style.strokeWidthPt != style.strokeWidthPt;
}

class _WeightPreview extends CustomPainter {
  _WeightPreview(this.weight);
  final double weight;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PlotUi.fg
      ..strokeWidth = weight.clamp(0.4, 4.0);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WeightPreview old) => old.weight != weight;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.offVariant = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool offVariant;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 30,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: PlotUi.rail,
            border: Border.all(color: PlotUi.border),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: enabled
                ? (offVariant ? PlotUi.mutedFg : PlotUi.dim)
                : PlotUi.mutedFg.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _ToolDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: PlotUi.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
