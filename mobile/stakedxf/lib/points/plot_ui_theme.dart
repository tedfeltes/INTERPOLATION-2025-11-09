import 'package:flutter/material.dart';

/// Compact, shadcn-inspired tokens for StakeDXF plot UI.
abstract final class PlotUi {
  static const bg = Color(0xFFFAFAFA);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4E7);
  static const muted = Color(0xFFF4F4F5);
  static const mutedFg = Color(0xFF71717A);
  static const fg = Color(0xFF09090B);
  static const accent = Color(0xFF18181B);
  static const accentFg = Color(0xFFFAFAFA);
  static const ring = Color(0xFFA1A1AA);
  static const destructive = Color(0xFFDC2626);
  static const selection = Color(0xFFE4572E);

  static const radius = 8.0;
  static const pad = 10.0;
  static const gap = 8.0;

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        surface: card,
        onSurface: fg,
        outline: border,
        primary: accent,
        onPrimary: accentFg,
        secondary: muted,
        onSecondary: fg,
        error: destructive,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: ring, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border),
        ),
      ),
    );
  }

  static BoxDecoration panel({bool selected = false}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected ? selection : border,
          width: selected ? 1.4 : 1,
        ),
      );

  static TextStyle get sectionLabel => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: mutedFg,
      );

  static TextStyle get body => const TextStyle(fontSize: 12.5, color: fg);
  static TextStyle get tiny => const TextStyle(fontSize: 11, color: mutedFg);
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
