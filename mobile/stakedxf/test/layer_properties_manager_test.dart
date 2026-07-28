import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/ctb_plot_style.dart';
import 'package:stakedxf/points/layer_properties_manager.dart';
import 'package:stakedxf/points/linetype_catalog.dart';

/// Regression test for the OLDE_HIGHLANDER field bug where the
/// "GLOBAL LTS" slider footer painted on top of the layer rows and
/// following sticky sections. Root cause: `_grid` capped its `SizedBox`
/// at `_rowHeight * 13` regardless of layer count, so a 107-layer DXF
/// still rendered every row in the inner Column and overflowed. The fix
/// sizes the SizedBox to the true row count.
void main() {
  testWidgets(
      'LayerPropertiesManager sizes itself to fit ALL layer rows so the '
      'GLOBAL LTS footer never overlaps the grid', (tester) async {
    final layers = <String>[
      for (var i = 0; i < 107; i++) 'LAYER-${i.toString().padLeft(3, '0')}',
    ];
    final selected = {layers.first};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            // Simulate the export screen viewport width so horizontal
            // overflow in unrelated toolbars can't mask the vertical fix.
            width: 900,
            child: SingleChildScrollView(
              child: LayerPropertiesManager(
                layers: layers,
                layerStyles: const {},
                selectedLayers: selected,
                lockedLayers: const {},
                layerOverrides: const {},
                catalog: LinetypeCatalog.builtin(),
                ctb: CtbPlotStyleTable.builtin(),
                globalLinetypeScale: 1.0,
                selectedLayer: null,
                entityCounts: {for (final l in layers) l: 1},
                onToggleLayer: (_) {},
                onToggleLock: (_) {},
                onSelectLayer: (_) {},
                onApplyLayerOverride: (_, __) {},
                onGlobalLinetypeScale: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException(); // drain any unrelated pre-existing overflows

    // The GLOBAL LTS footer text must appear STRICTLY BELOW every layer
    // row on the vertical axis. Before the fix the footer sat at
    // `y ≈ _rowHeight * 13` while the (unclipped) grid Column continued
    // painting layers down to `y ≈ _rowHeight * 107` — i.e. the footer
    // landed in the middle of the layer list.
    final footerRect = tester.getRect(find.text('GLOBAL  LTS'));
    // The last visible layer row (deep in the list) has an entity count
    // text of "1" plus its LAYER-XXX name. Look up the last layer name.
    final lastLayerFinder = find.text(layers.last);
    expect(lastLayerFinder, findsOneWidget);
    final lastLayerRect = tester.getRect(lastLayerFinder);
    expect(
      footerRect.top,
      greaterThan(lastLayerRect.bottom),
      reason:
          'GLOBAL LTS footer must render below the last layer row; it '
          'used to overlap the grid when the SizedBox height was capped '
          'at 12 rows regardless of layer count.',
    );

    expect(find.text('LAYER PROPERTIES MANAGER'), findsOneWidget);
  });
}
