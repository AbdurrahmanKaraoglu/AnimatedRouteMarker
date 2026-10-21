import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Spherical-earth helpers used by the animation: great-circle distance,
/// bearing, interpolation and angle smoothing.
///
/// All functions are pure Dart and side-effect free.
abstract final class GeoMath {
  /// Mean earth radius in meters (IUGG).
  static const double earthRadius = 6371008.8;

  static double _rad(double degrees) => degrees * math.pi / 180;

  static double _deg(double radians) => radians * 180 / math.pi;

  /// Great-circle distance between [a] and [b] in meters (haversine).
  static double distance(LatLng a, LatLng b) => earthRadius * _angularDistance(a, b);

  static double _angularDistance(LatLng a, LatLng b) {
    final double lat1 = _rad(a.latitude);
    final double lat2 = _rad(b.latitude);
    final double dLat = lat2 - lat1;
    final double dLng = _rad(b.longitude - a.longitude);
    final double h =
        math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Initial bearing from [from] to [to] in degrees, clockwise from north,
  /// in the range `[0, 360)`. Returns 0 when the points are the same.
  static double bearing(LatLng from, LatLng to) {
    final double lat1 = _rad(from.latitude);
    final double lat2 = _rad(to.latitude);
    final double dLng = _rad(to.longitude - from.longitude);
    final double y = math.sin(dLng) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    if (x == 0 && y == 0) {
      return 0;
    }
    return normalizeAngle(_deg(math.atan2(y, x)));
  }

  /// The point at [fraction] (0 = [a], 1 = [b]) of the great-circle path
  /// from [a] to [b].
  static LatLng interpolate(LatLng a, LatLng b, double fraction) {
    if (fraction <= 0) {
      return a;
    }
    if (fraction >= 1) {
      return b;
    }
    final double delta = _angularDistance(a, b);
    // Below ~6 m the spherical formula loses precision; a plain lerp is
    // indistinguishable there. The longitude takes the short way round the
    // antimeridian.
    if (delta < 1e-6) {
      final double dLng = shortestAngleDelta(a.longitude, b.longitude);
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * fraction,
        a.longitude + dLng * fraction,
      );
    }
    final double lat1 = _rad(a.latitude);
    final double lng1 = _rad(a.longitude);
    final double lat2 = _rad(b.latitude);
    final double lng2 = _rad(b.longitude);
    final double sinDelta = math.sin(delta);
    final double wa = math.sin((1 - fraction) * delta) / sinDelta;
    final double wb = math.sin(fraction * delta) / sinDelta;
    final double x = wa * math.cos(lat1) * math.cos(lng1) + wb * math.cos(lat2) * math.cos(lng2);
    final double y = wa * math.cos(lat1) * math.sin(lng1) + wb * math.cos(lat2) * math.sin(lng2);
    final double z = wa * math.sin(lat1) + wb * math.sin(lat2);
    return LatLng(
      _deg(math.atan2(z, math.sqrt(x * x + y * y))),
      _deg(math.atan2(y, x)),
    );
  }

  /// [degrees] wrapped into `[0, 360)`.
  static double normalizeAngle(double degrees) {
    final double value = degrees % 360;
    return value < 0 ? value + 360 : value;
  }

  /// The signed turn from [from] to [to] in degrees, in `(-180, 180]`, taking
  /// the short way round: 359° → 1° is +2°, not -358°.
  static double shortestAngleDelta(double from, double to) {
    final double delta = normalizeAngle(to - from);
    return delta > 180 ? delta - 360 : delta;
  }

  /// The angle at [t] between [from] and [to], turning the short way round.
  /// The result is in `[0, 360)`.
  static double lerpAngle(double from, double to, double t) => normalizeAngle(from + shortestAngleDelta(from, to) * t);
}
