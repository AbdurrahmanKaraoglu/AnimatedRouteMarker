import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A map-less preview used when there is no Google Maps key: draws the same
/// polylines and markers the map would get, on a plain projected canvas.
class RouteSketch extends StatelessWidget {
  const RouteSketch({
    super.key,
    required this.bounds,
    required this.markers,
    required this.polylines,
    required this.colors,
  });

  /// Points the view is fitted to.
  final List<LatLng> bounds;
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  /// Marker colors by marker id.
  final Map<MarkerId, Color> colors;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SketchPainter(this, scheme.outlineVariant, scheme.surface),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.sketch, this.gridColor, this.haloColor);

  final RouteSketch sketch;
  final Color gridColor;
  final Color haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final LatLng p in sketch.bounds) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // Equirectangular projection, good enough for a city.
    final double cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final double spanX = math.max((maxLng - minLng) * cosLat, 1e-9);
    final double spanY = math.max(maxLat - minLat, 1e-9);
    const double padding = 32;
    final double scale = math.min((size.width - padding * 2) / spanX, (size.height - padding * 2) / spanY);
    final Offset origin = Offset(
      (size.width - spanX * scale) / 2,
      (size.height - spanY * scale) / 2,
    );
    Offset project(LatLng p) => origin + Offset((p.longitude - minLng) * cosLat * scale, (maxLat - p.latitude) * scale);

    final List<Polyline> lines = sketch.polylines.toList()..sort((Polyline a, Polyline b) => a.zIndex - b.zIndex);
    for (final Polyline line in lines) {
      if (line.points.length < 2) {
        continue;
      }
      final Path path = Path()..moveTo(project(line.points.first).dx, project(line.points.first).dy);
      for (final LatLng p in line.points.skip(1)) {
        final Offset o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = line.width.toDouble()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final Marker marker in sketch.markers) {
      final Offset center = project(marker.position);
      final Color color = sketch.colors[marker.markerId] ?? Colors.black;
      canvas.drawCircle(center, 13, Paint()..color = haloColor);
      canvas.drawCircle(center, 11, Paint()..color = color);
      // An arrow pointing in the marker's heading (north is up).
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(marker.rotation * math.pi / 180);
      canvas.drawPath(
        Path()
          ..moveTo(0, -7)
          ..lineTo(5, 5)
          ..lineTo(0, 2)
          ..lineTo(-5, 5)
          ..close(),
        Paint()..color = Colors.white,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SketchPainter oldDelegate) => true;
}
