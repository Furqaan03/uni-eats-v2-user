import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../models/campus_location_model.dart';

/// Custom vector-ish campus map for UDST.
/// Coordinates are normalized to [0, 1]. The painter maps them onto
/// the canvas while preserving the aspect ratio of the source map.
class CampusMapPainter extends CustomPainter {
  final List<CampusLocationModel> locations;
  final Offset? driverPosition;
  final Offset? destinationPosition;
  final CampusLocationModel? selectedLocation;

  CampusMapPainter({
    required this.locations,
    this.driverPosition,
    this.destinationPosition,
    this.selectedLocation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mapRect = _mapRect(size);

    _paintBackground(canvas, mapRect);
    _paintBlocks(canvas, mapRect);
    _paintPaths(canvas, mapRect);
    _paintLocations(canvas, mapRect);

    if (destinationPosition != null) {
      _paintDestination(canvas, mapRect);
    }

    if (driverPosition != null) {
      _paintDriver(canvas, mapRect);
    }
  }

  Rect _mapRect(Size size) {
    const sourceAspect = 1198 / 775;
    double width = size.width;
    double height = size.height;

    if (width / height > sourceAspect) {
      width = height * sourceAspect;
    } else {
      height = width / sourceAspect;
    }

    return Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
  }

  void _paintBackground(Canvas canvas, Rect rect) {
    final paint = Paint()..color = const Color(0xFFF1F5ED);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );
  }

  void _paintBlocks(Canvas canvas, Rect rect) {
    final blockPaint = Paint()
      ..color = const Color(0xFFE1E8DB)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFFBFC9B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final blocks = <Rect>[
      Rect.fromLTWH(0.08, 0.14, 0.20, 0.24),
      Rect.fromLTWH(0.32, 0.10, 0.18, 0.28),
      Rect.fromLTWH(0.58, 0.08, 0.16, 0.26),
      Rect.fromLTWH(0.78, 0.12, 0.16, 0.22),
      Rect.fromLTWH(0.10, 0.46, 0.22, 0.20),
      Rect.fromLTWH(0.40, 0.44, 0.22, 0.24),
      Rect.fromLTWH(0.70, 0.42, 0.20, 0.26),
      Rect.fromLTWH(0.08, 0.72, 0.26, 0.18),
      Rect.fromLTWH(0.44, 0.74, 0.20, 0.16),
      Rect.fromLTWH(0.72, 0.70, 0.18, 0.18),
    ];

    for (final b in blocks) {
      final r = _normRectToRect(b, rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        blockPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        outlinePaint,
      );
    }
  }

  void _paintPaths(Canvas canvas, Rect rect) {
    final pathPaint = Paint()
      ..color = const Color(0xFFCAD4C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final nodes = [
      Offset(0.12, 0.48),
      Offset(0.18, 0.48),
      Offset(0.22, 0.44),
      Offset(0.28, 0.44),
      Offset(0.34, 0.40),
      Offset(0.42, 0.42),
      Offset(0.48, 0.42),
      Offset(0.56, 0.38),
      Offset(0.62, 0.40),
      Offset(0.68, 0.42),
      Offset(0.74, 0.42),
      Offset(0.80, 0.44),
      Offset(0.86, 0.42),
    ];

    if (nodes.isNotEmpty) {
      final start = _normToOffset(nodes.first, rect);
      path.moveTo(start.dx, start.dy);
      for (int i = 1; i < nodes.length; i++) {
        final p = _normToOffset(nodes[i], rect);
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(path, pathPaint);
  }

  void _paintLocations(Canvas canvas, Rect rect) {
    for (final loc in locations) {
      final center = _normToOffset(Offset(loc.x, loc.y), rect);
      final isSelected = selectedLocation?.id == loc.id;

      final color = switch (loc.type) {
        CampusLocationType.restaurant => AppColors.primary,
        CampusLocationType.academic => const Color(0xFF6B7A9A),
        CampusLocationType.residential => const Color(0xFFD9A66C),
        CampusLocationType.facility => const Color(0xFF9AA0A8),
        CampusLocationType.parking => const Color(0xFF5E8B7E),
      };

      final radius = isSelected ? 12.0 : 8.0;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final outlinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(center, radius, outlinePaint);

      if (isSelected) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: loc.label,
            style: const TextStyle(
              color: Color(0xFF202124),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              backgroundColor: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            center.dx - labelPainter.width / 2,
            center.dy - radius - labelPainter.height - 6,
          ),
        );
      }
    }
  }

  void _paintDestination(Canvas canvas, Rect rect) {
    if (destinationPosition == null) return;
    final center = _normToOffset(destinationPosition!, rect);

    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, 10, paint);
    canvas.drawCircle(center, 10, outlinePaint);
  }

  void _paintDriver(Canvas canvas, Rect rect) {
    if (driverPosition == null) return;
    final center = _normToOffset(driverPosition!, rect);

    final pulsePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final bodyPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, 24, pulsePaint);
    canvas.drawCircle(center, 10, bodyPaint);
    canvas.drawCircle(center, 10, outlinePaint);
  }

  Offset _normToOffset(Offset norm, Rect rect) {
    return Offset(
      rect.left + norm.dx * rect.width,
      rect.top + norm.dy * rect.height,
    );
  }

  Rect _normRectToRect(Rect norm, Rect rect) {
    return Rect.fromLTWH(
      rect.left + norm.left * rect.width,
      rect.top + norm.top * rect.height,
      norm.width * rect.width,
      norm.height * rect.height,
    );
  }

  @override
  bool shouldRepaint(covariant CampusMapPainter oldDelegate) {
    return oldDelegate.driverPosition != driverPosition ||
        oldDelegate.destinationPosition != destinationPosition ||
        oldDelegate.selectedLocation != selectedLocation ||
        !listEquals(oldDelegate.locations, locations);
  }
}

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
