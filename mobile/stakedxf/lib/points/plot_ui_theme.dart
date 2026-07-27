import 'package:flutter/material.dart';

/// StakeDXF instrument-grade design system.
///
/// Rugged, futuristic, minimalist. Hard 90° corners, hairline rules,
/// safety-orange as a *functional* color only (active / primary / warning),
/// monospaced telemetry text for coordinates, versions, and layer counts.
abstract final class PlotUi {
  // Surface stack — cool graphite instead of green wash.
  static const bg = Color(0xFF080A0C);
  static const card = Color(0xFF10131A);
  static const elevated = Color(0xFF161A22);
  static const rail = Color(0xFF1D222B);
  static const muted = Color(0xFF141821);
  static const mutedFg = Color(0xFF7A8595);

  // Ink.
  static const fg = Color(0xFFF2F4F7);
  static const dim = Color(0xFFC7CBD1);

  // Instrument accents.
  static const accent = Color(0xFFFF5A1F); // safety orange, only for action
  static const accentFg = Color(0xFF130803);
  static const accentDim = Color(0x33FF5A1F);
  static const ring = Color(0xFFFF5A1F);
  static const ok = Color(0xFF7FE0A0);
  static const warn = Color(0xFFF2C15A);
  static const destructive = Color(0xFFE5484D);
  static const selection = accent;

  // Grid / hairlines.
  static const border = Color(0xFF262B36);
  static const borderStrong = Color(0xFF3B4150);

  static const radius = 0.0;
  static const pad = 12.0;
  static const gap = 10.0;

  static BorderRadius get sharp => BorderRadius.circular(radius);

  static ThemeData theme(BuildContext context) {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: accentFg,
      secondary: ok,
      onSecondary: Color(0xFF08120C),
      error: destructive,
      onError: Color(0xFF1A0303),
      surface: card,
      onSurface: fg,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: rail,
      surfaceContainerHigh: elevated,
      surfaceContainer: card,
      surfaceContainerLow: bg,
      surfaceContainerLowest: bg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: NoSplash.splashFactory,
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
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(color: mutedFg, fontSize: 12.5),
        labelStyle: const TextStyle(color: mutedFg, fontSize: 11, letterSpacing: 0.8),
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
          borderSide: const BorderSide(color: ring, width: 1.4),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: muted,
        selectedColor: rail,
        disabledColor: muted,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelPadding: EdgeInsets.symmetric(horizontal: 2),
        labelStyle: TextStyle(
          color: fg,
          fontSize: 11,
          fontFamily: 'monospace',
          letterSpacing: 0.6,
        ),
        secondaryLabelStyle: TextStyle(color: mutedFg, fontSize: 11),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentFg,
          disabledBackgroundColor: rail,
          disabledForegroundColor: mutedFg,
          visualDensity: VisualDensity.compact,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: const BorderSide(color: border, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dim,
          visualDensity: VisualDensity.compact,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        showDragHandle: true,
        dragHandleColor: borderStrong,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: rail,
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
          if (s.contains(WidgetState.selected)) return accentDim;
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
        side: const BorderSide(color: borderStrong, width: 1.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: border,
        thumbColor: accent,
        overlayColor: accentDim,
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1),
        activeTickMarkColor: accent,
        inactiveTickMarkColor: border,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: mutedFg,
        indicatorColor: accent,
        dividerColor: border,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border),
        ),
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
            RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: border),
            ),
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

  static BoxDecoration panel({bool selected = false}) =>
      panelBox(selected: selected);

  static TextStyle get sectionLabel => const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: mutedFg,
        fontFamily: 'monospace',
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
        color: dim,
        fontFamily: 'monospace',
        letterSpacing: 0.4,
      );

  static TextStyle get monoLabel => const TextStyle(
        fontSize: 10.5,
        color: mutedFg,
        fontFamily: 'monospace',
        letterSpacing: 1.6,
        fontWeight: FontWeight.w800,
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
