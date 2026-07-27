import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

/// Civil 3D–style ANSI31 diagonal hatch (outline + hatch, never solid fill).
void hatchFlutterPath(
  Canvas canvas,
  Path path,
  Color color, {
  double strokeWidth = 1.2,
  double spacing = 4.5,
  double angleDeg = 45,
}) {
  final bounds = path.getBounds();
  if (bounds.isEmpty) return;

  final outline = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeJoin = StrokeJoin.round;

  final hatch = Paint()
    ..color = color.withValues(alpha: (color.a).clamp(0.35, 1.0))
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.7, strokeWidth * 0.55);

  canvas.drawPath(path, outline);

  canvas.save();
  canvas.clipPath(path);
  final rad = angleDeg * math.pi / 180;
  final cosA = math.cos(rad);
  final sinA = math.sin(rad);
  final diag = math.sqrt(
        bounds.width * bounds.width + bounds.height * bounds.height,
      ) +
      spacing * 2;
  final cx = bounds.center.dx;
  final cy = bounds.center.dy;
  // Perpendicular direction for stepping hatch lines.
  final nx = -sinA;
  final ny = cosA;
  final steps = (diag * 2 / spacing).ceil();
  for (var i = -steps; i <= steps; i++) {
    final ox = cx + nx * i * spacing;
    final oy = cy + ny * i * spacing;
    final a = Offset(ox - cosA * diag, oy - sinA * diag);
    final b = Offset(ox + cosA * diag, oy + sinA * diag);
    canvas.drawLine(a, b, hatch);
  }
  canvas.restore();
}

/// Hatch a closed ellipse (circle) with Civil-style ANSI31 lines.
void hatchFlutterCircle(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double strokeWidth = 1.2,
  double spacing = 4.0,
}) {
  final path = Path()
    ..addOval(Rect.fromCircle(center: center, radius: radius));
  hatchFlutterPath(
    canvas,
    path,
    color,
    strokeWidth: strokeWidth,
    spacing: spacing,
  );
}

/// PDF hatch: clip to current path then stroke ANSI31 diagonals.
void hatchPdfClosedPath(
  PdfGraphics canvas,
  void Function(PdfGraphics c) buildClosedPath,
  PdfColor color, {
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  double strokeWidth = 0.9,
  double spacing = 3.5,
  double angleDeg = 45,
}) {
  canvas
    ..saveContext()
    ..setStrokeColor(color)
    ..setFillColor(color)
    ..setLineWidth(strokeWidth);
  buildClosedPath(canvas);
  canvas
    ..strokePath()
    ..saveContext();
  buildClosedPath(canvas);
  canvas.clipPath();

  final rad = angleDeg * math.pi / 180;
  final cosA = math.cos(rad);
  final sinA = math.sin(rad);
  final cx = (minX + maxX) / 2;
  final cy = (minY + maxY) / 2;
  final w = maxX - minX;
  final h = maxY - minY;
  final diag = math.sqrt(w * w + h * h) + spacing * 2;
  final nx = -sinA;
  final ny = cosA;
  final steps = (diag * 2 / spacing).ceil();
  canvas.setLineWidth(math.max(0.4, strokeWidth * 0.55));
  for (var i = -steps; i <= steps; i++) {
    final ox = cx + nx * i * spacing;
    final oy = cy + ny * i * spacing;
    canvas.drawLine(
      ox - cosA * diag,
      oy - sinA * diag,
      ox + cosA * diag,
      oy + sinA * diag,
    );
  }
  canvas
    ..strokePath()
    ..restoreContext()
    ..restoreContext();
}

void hatchPdfCircle(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r,
  PdfColor color, {
  double strokeWidth = 0.9,
  double spacing = 3.2,
}) {
  hatchPdfClosedPath(
    canvas,
    (c) {
      c.drawEllipse(cx, cy, r, r);
    },
    color,
    minX: cx - r,
    minY: cy - r,
    maxX: cx + r,
    maxY: cy + r,
    strokeWidth: strokeWidth,
    spacing: spacing,
  );
}

/// Apply opacity to an ARGB color.
int applyOpacityArgb(int argb, double opacity) {
  final a = (opacity.clamp(0.05, 1.0) * 255).round();
  return (a << 24) | (argb & 0x00FFFFFF);
}

Color colorWithOpacityArgb(int argb, double opacity) {
  return Color(applyOpacityArgb(argb, opacity));
}
