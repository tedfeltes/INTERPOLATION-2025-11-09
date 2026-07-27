import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'block_catalog.dart';
import 'hatch_paint.dart';
import 'plot_symbols.dart';

/// Tiny preview icon for the symbol library picker (hatched, not solid fill).
class SymbolPreviewPainter extends CustomPainter {
  SymbolPreviewPainter(
    this.kind, {
    this.color = const Color(0xFFE4572E),
    this.opacity = 1.0,
  });

  final PlotSymbolKind kind;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paintColor = color.withValues(alpha: opacity.clamp(0.05, 1.0));
    final stroke = Paint()
      ..color = paintColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final h = math.min(size.width, size.height) * 0.35;

    switch (kind) {
      case PlotSymbolKind.stopSign:
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final a = -math.pi / 8 + i * math.pi / 4;
          final x = cx + math.cos(a) * h;
          final y = cy + math.sin(a) * h;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        hatchFlutterPath(canvas, path, paintColor, spacing: 3.2);
        return;
      case PlotSymbolKind.yieldSign:
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - h)
            ..lineTo(cx - h, cy + h * 0.8)
            ..lineTo(cx + h, cy + h * 0.8)
            ..close(),
          stroke,
        );
        return;
      case PlotSymbolKind.noOutlet:
      case PlotSymbolKind.pedCrossing:
      case PlotSymbolKind.bikeCrossing:
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy - h)
            ..lineTo(cx + h, cy)
            ..lineTo(cx, cy + h)
            ..lineTo(cx - h, cy)
            ..close(),
          stroke,
        );
        return;
      case PlotSymbolKind.siltFence:
      case PlotSymbolKind.wattle:
        canvas.drawLine(Offset(cx - h, cy), Offset(cx + h, cy), stroke);
        for (var i = -2; i <= 2; i++) {
          canvas.drawLine(
            Offset(cx + i * h / 2.5, cy),
            Offset(cx + i * h / 2.5, cy - h * 0.6),
            stroke,
          );
        }
        return;
      case PlotSymbolKind.noteBox:
      case PlotSymbolKind.detailRef:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: h * 2.2,
              height: h * 1.3,
            ),
            const Radius.circular(2),
          ),
          stroke,
        );
        return;
      default:
        canvas.drawCircle(Offset(cx, cy), h, stroke);
        hatchFlutterCircle(
          canvas,
          Offset(cx, cy),
          h * 0.35,
          paintColor,
          spacing: 2.8,
        );
        return;
    }
  }

  @override
  bool shouldRepaint(covariant SymbolPreviewPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}

/// Preview painter for extracted DWG block geometry.
class BlockPreviewPainter extends CustomPainter {
  BlockPreviewPainter(
    this.block, {
    this.color = const Color(0xFFE4572E),
    this.opacity = 1.0,
  });

  final DwgBlockSymbol block;
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0.05, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = math.min(size.width, size.height) * 0.75;
    for (final path in block.paths) {
      if (path.points.length < 2) continue;
      final p = Path();
      final first = path.points.first;
      p.moveTo(cx + first[0] * s, cy - first[1] * s);
      for (var i = 1; i < path.points.length; i++) {
        final pt = path.points[i];
        p.lineTo(cx + pt[0] * s, cy - pt[1] * s);
      }
      if (path.closed) {
        p.close();
        // Closed block paths: Civil-style hatch instead of solid fill.
        hatchFlutterPath(
          canvas,
          p,
          color.withValues(alpha: opacity.clamp(0.05, 1.0)),
          spacing: 3.5,
        );
      } else {
        canvas.drawPath(p, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BlockPreviewPainter oldDelegate) =>
      oldDelegate.block.id != block.id ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}
