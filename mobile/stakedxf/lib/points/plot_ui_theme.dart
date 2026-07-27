import 'package:flutter/material.dart';

/// Dark, sharp, utilitarian tokens for StakeDXF UI.
///
/// Field-instrument look: near-black panels, hairline borders, zero radius,
/// dense type — no soft cards or light-mode chrome.
abstract final class PlotUi {
  static const bg = Color(0xFF0C0E0C);
  static const card = Color(0xFF141814);
  static const elevated = Color(0xFF1A1F1A);
  static const border = Color(0xFF2E362E);
  static const muted = Color(0xFF1E241E);
  static const mutedFg = Color(0xFF8A9688);
  static const fg = Color(0xFFE6EBE4);
  static const accent = Color(0xFFE4572E);
  static const accentFg = Color(0xFF1A0D08);
  static const ring = Color(0xFFE4572E);
  static const destructive = Color(0xFFE87474);
  static const selection = Color(0xFFE4572E);
  static const ok = Color(0xFF6F9B5A);

  /// Sharp edges throughout — no rounded chrome.
  static const radius = 0.0;
  static const pad = 10.0;
  static const gap = 8.0;

  static BorderRadius get sharp => BorderRadius.circular(radius);

  static ThemeData theme(BuildContext context) {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: accentFg,
      secondary: ok,
      onSecondary: Color(0xFF0C0E0C),
      error: destructive,
      onError: Color(0xFF1A0D08),
      surface: card,
      onSurface: fg,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: elevated,
      surfaceContainerHigh: muted,
      surfaceContainer: card,
      surfaceContainerLow: bg,
      surfaceContainerLowest: bg,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: sharp,
      side: const BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: fg,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintStyle: const TextStyle(color: mutedFg, fontSize: 12.5),
        labelStyle: const TextStyle(color: mutedFg, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: sharp,
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: sharp,
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: sharp,
          borderSide: const BorderSide(color: ring, width: 1),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: muted,
        selectedColor: elevated,
        disabledColor: muted,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: EdgeInsets.symmetric(horizontal: 6),
        labelPadding: EdgeInsets.symmetric(horizontal: 2),
        labelStyle: TextStyle(color: fg, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: mutedFg, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentFg,
          disabledBackgroundColor: muted,
          disabledForegroundColor: mutedFg,
          visualDensity: VisualDensity.compact,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          side: const BorderSide(color: border),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: fg,
          visualDensity: VisualDensity.compact,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        showDragHandle: true,
        dragHandleColor: border,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: fg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return accent;
          return mutedFg;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.35);
          }
          return muted;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(accentFg),
        side: const BorderSide(color: border, width: 1.2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: Color(0x33E4572E),
        trackHeight: 2,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: mutedFg,
        indicatorColor: accent,
        dividerColor: border,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        iconColor: mutedFg,
        textColor: fg,
        tileColor: Colors.transparent,
        selectedTileColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: muted,
          border: OutlineInputBorder(
            borderRadius: sharp,
            borderSide: const BorderSide(color: border),
          ),
        ),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(card),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
      ),
    );
  }

  static BoxDecoration panelBox({bool selected = false}) => BoxDecoration(
        color: card,
        borderRadius: sharp,
        border: Border.all(
          color: selected ? selection : border,
          width: selected ? 1.5 : 1,
        ),
      );

  /// Alias kept for call sites that used [panel].
  static BoxDecoration panel({bool selected = false}) =>
      panelBox(selected: selected);

  static TextStyle get sectionLabel => const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: mutedFg,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 12.5,
        color: fg,
        height: 1.3,
      );

  static TextStyle get tiny => const TextStyle(
        fontSize: 11,
        color: mutedFg,
        height: 1.25,
      );

  static TextStyle get mono => const TextStyle(
        fontSize: 11.5,
        color: mutedFg,
        fontFamily: 'monospace',
        letterSpacing: 0.2,
      );
}

/// Standard civil engineering scales (feet per inch).
const kEngineeringScalePresets = <double>[
  10, 20, 30, 40, 50, 60, 80, 100, 150, 200, 300, 400, 500, 600, 800, 1000,
  1200, 1500, 2000, 2500, 3000, 4000, 5000,
];

String engineeringScaleLabel(double ftPerInch) {
  final n = ftPerInch == ftPerInch.roundToDouble()
      ? ftPerInch.round().toString()
      : ftPerInch.toStringAsFixed(1);
  return '1"=$n\'';
}
