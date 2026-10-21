import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_math.dart';

/// A position on a [RoutePath].
class RoutePosition {
  const RoutePosition(this.position, this.bearing, this.segmentIndex);

  /// The point on the route.
  final LatLng position;

  /// Direction of travel at [position], in degrees clockwise from north.
  final double bearing;

  /// Index of the route point the current segment starts at.
  final int segmentIndex;
}

/// A polyline with precomputed segment lengths, so positions along it can be
/// looked up by distance from the start.
class RoutePath {
  /// Builds a path from [points]. Consecutive duplicate points are kept but
  /// add no length. Throws an [ArgumentError] if [points] is empty.
  RoutePath(List<LatLng> points) : points = List<LatLng>.unmodifiable(points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'must not be empty');
    }
    final List<double> cumulative = <double>[0];
    final List<double> bearings = <double>[];
    for (int i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + GeoMath.distance(points[i - 1], points[i]));
      bearings.add(GeoMath.bearing(points[i - 1], points[i]));
    }
    _cumulative = cumulative;
    _bearings = _fillZeroLengthBearings(bearings, cumulative);
  }

  /// The route points.
  final List<LatLng> points;

  late final List<double> _cumulative;
  late final List<double> _bearings;

  /// Total length in meters.
  double get length => _cumulative.last;

  /// Distance from the start to `points[index]` in meters.
  double distanceAt(int index) => _cumulative[index];

  /// A zero-length segment has no direction of its own; it takes the one of
  /// the previous moving segment (or the next one at the start).
  static List<double> _fillZeroLengthBearings(List<double> bearings, List<double> cumulative) {
    final List<double> result = List<double>.of(bearings);
    int firstMoving = -1;
    for (int i = 0; i < result.length; i++) {
      if (cumulative[i + 1] > cumulative[i]) {
        firstMoving = firstMoving < 0 ? i : firstMoving;
      } else if (i > 0) {
        result[i] = result[i - 1];
      }
    }
    for (int i = 0; i < firstMoving; i++) {
      result[i] = result[firstMoving];
    }
    return result;
  }

  /// Index of the segment that contains [distance] (binary search).
  int segmentAt(double distance) {
    if (points.length < 2 || distance <= 0) {
      return 0;
    }
    if (distance >= length) {
      return points.length - 2;
    }
    int low = 0;
    int high = points.length - 2;
    while (low < high) {
      final int mid = (low + high + 1) >> 1;
      if (_cumulative[mid] <= distance) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// The point [distance] meters from the start, clamped to the route, with
  /// the direction of travel there.
  RoutePosition positionAt(double distance) {
    if (points.length == 1) {
      return RoutePosition(points.first, 0, 0);
    }
    final double clamped = distance.clamp(0, length).toDouble();
    final int index = segmentAt(clamped);
    final LatLng start = points[index];
    final LatLng end = points[index + 1];
    final double segmentLength = _cumulative[index + 1] - _cumulative[index];
    if (segmentLength <= 0) {
      return RoutePosition(start, _bearings[index], index);
    }
    final double fraction = (clamped - _cumulative[index]) / segmentLength;
    final LatLng position = GeoMath.interpolate(start, end, fraction);
    // On a long segment the great-circle heading changes along the way, so it
    // is measured from the current point; near the end the segment's own
    // heading is used to avoid noise.
    final double bearing =
        segmentLength - (clamped - _cumulative[index]) > 1 ? GeoMath.bearing(position, end) : _bearings[index];
    return RoutePosition(position, bearing, index);
  }

  /// The points from the start up to [distance], ending exactly there.
  List<LatLng> passedPoints(double distance) {
    final RoutePosition at = positionAt(distance);
    return <LatLng>[...points.sublist(0, at.segmentIndex + 1), at.position];
  }

  /// The points from [distance] to the end, starting exactly there.
  List<LatLng> remainingPoints(double distance) {
    if (points.length == 1) {
      return <LatLng>[points.first];
    }
    final RoutePosition at = positionAt(distance);
    return <LatLng>[at.position, ...points.sublist(at.segmentIndex + 1)];
  }
}
