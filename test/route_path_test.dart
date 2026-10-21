import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  // An L-shaped route: one degree north, then one degree east.
  const List<LatLng> lShape = <LatLng>[LatLng(0, 0), LatLng(1, 0), LatLng(1, 1)];

  test('empty route throws', () {
    expect(() => RoutePath(const <LatLng>[]), throwsArgumentError);
  });

  test('single point has zero length', () {
    final RoutePath path = RoutePath(const <LatLng>[LatLng(41, 29)]);
    expect(path.length, 0);
    expect(path.positionAt(100).position, const LatLng(41, 29));
    expect(path.remainingPoints(0), const <LatLng>[LatLng(41, 29)]);
  });

  test('length is the sum of the segments', () {
    final RoutePath path = RoutePath(lShape);
    final double expected = GeoMath.distance(lShape[0], lShape[1]) + GeoMath.distance(lShape[1], lShape[2]);
    expect(path.length, closeTo(expected, 1e-6));
    expect(path.distanceAt(1), closeTo(GeoMath.distance(lShape[0], lShape[1]), 1e-6));
  });

  test('positionAt walks the segments with their bearings', () {
    final RoutePath path = RoutePath(lShape);
    final double first = path.distanceAt(1);

    final RoutePosition start = path.positionAt(0);
    expect(start.position, lShape[0]);
    expect(start.bearing, closeTo(0, 1e-6));
    expect(start.segmentIndex, 0);

    final RoutePosition halfway = path.positionAt(first / 2);
    expect(halfway.position.latitude, closeTo(0.5, 1e-9));
    expect(halfway.segmentIndex, 0);

    final RoutePosition second = path.positionAt(first + 1000);
    expect(second.segmentIndex, 1);
    expect(second.bearing, closeTo(90, 0.1));

    expect(path.positionAt(path.length + 500).position, lShape[2]);
    expect(path.positionAt(-5).position, lShape[0]);
  });

  test('segmentAt finds the segment on long routes', () {
    final List<LatLng> points = <LatLng>[for (int i = 0; i <= 1000; i++) LatLng(0, i / 1000)];
    final RoutePath path = RoutePath(points);
    for (final int i in <int>[0, 1, 250, 999]) {
      expect(path.segmentAt(path.distanceAt(i) + 1), i);
    }
    expect(path.segmentAt(path.length), 999);
  });

  test('duplicate points add no length and keep the heading', () {
    final RoutePath path = RoutePath(
      const <LatLng>[LatLng(0, 0), LatLng(0, 0), LatLng(0, 1), LatLng(0, 1), LatLng(1, 1)],
    );
    expect(path.length, closeTo(2 * 111195.08, 0.1));
    // The leading zero-length segment takes the heading of the first move.
    expect(path.positionAt(0).bearing, closeTo(90, 1e-6));
    expect(path.positionAt(path.distanceAt(2)).position, const LatLng(0, 1));
  });

  test('passed and remaining points meet at the current position', () {
    final RoutePath path = RoutePath(lShape);
    final double at = path.distanceAt(1) + 5000;
    final List<LatLng> passed = path.passedPoints(at);
    final List<LatLng> remaining = path.remainingPoints(at);
    expect(passed.sublist(0, 2), lShape.sublist(0, 2));
    expect(passed.last, remaining.first);
    expect(remaining.last, lShape.last);
    expect(remaining.length, 2);
  });
}
