import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const LatLng istanbul = LatLng(41.0082, 28.9784);
  const LatLng ankara = LatLng(39.9334, 32.8597);
  const LatLng london = LatLng(51.5074, -0.1278);
  const LatLng newYork = LatLng(40.7128, -74.0060);

  group('distance', () {
    test('one degree on the equator', () {
      expect(GeoMath.distance(const LatLng(0, 0), const LatLng(0, 1)), closeTo(111195.08, 0.01));
      expect(GeoMath.distance(const LatLng(0, 0), const LatLng(1, 0)), closeTo(111195.08, 0.01));
    });

    test('Istanbul to Ankara', () {
      expect(GeoMath.distance(istanbul, ankara), closeTo(349356.22, 0.01));
    });

    test('is symmetric and zero for the same point', () {
      expect(GeoMath.distance(london, newYork), closeTo(GeoMath.distance(newYork, london), 1e-6));
      expect(GeoMath.distance(istanbul, istanbul), 0);
    });

    test('across the antimeridian takes the short way', () {
      expect(GeoMath.distance(const LatLng(0, 179.5), const LatLng(0, -179.5)), closeTo(111195.08, 0.01));
    });
  });

  group('bearing', () {
    test('cardinal directions', () {
      const LatLng origin = LatLng(0, 0);
      expect(GeoMath.bearing(origin, const LatLng(1, 0)), closeTo(0, 1e-9));
      expect(GeoMath.bearing(origin, const LatLng(0, 1)), closeTo(90, 1e-9));
      expect(GeoMath.bearing(origin, const LatLng(-1, 0)), closeTo(180, 1e-9));
      expect(GeoMath.bearing(origin, const LatLng(0, -1)), closeTo(270, 1e-9));
    });

    test('known city pairs', () {
      expect(GeoMath.bearing(istanbul, ankara), closeTo(108.7349, 1e-4));
      expect(GeoMath.bearing(london, newYork), closeTo(288.3297, 1e-4));
    });

    test('same point is 0', () {
      expect(GeoMath.bearing(istanbul, istanbul), 0);
    });

    test('crossing the antimeridian eastwards is 90', () {
      expect(GeoMath.bearing(const LatLng(0, 179.5), const LatLng(0, -179.5)), closeTo(90, 1e-9));
    });
  });

  group('interpolate', () {
    test('end points', () {
      expect(GeoMath.interpolate(istanbul, ankara, 0), istanbul);
      expect(GeoMath.interpolate(istanbul, ankara, 1), ankara);
      expect(GeoMath.interpolate(istanbul, ankara, -1), istanbul);
      expect(GeoMath.interpolate(istanbul, ankara, 2), ankara);
    });

    test('point at a fraction is at that fraction of the distance', () {
      final double total = GeoMath.distance(istanbul, ankara);
      for (final double f in <double>[0.1, 0.25, 0.5, 0.9]) {
        final LatLng p = GeoMath.interpolate(istanbul, ankara, f);
        expect(GeoMath.distance(istanbul, p), closeTo(total * f, 0.01));
        expect(GeoMath.distance(p, ankara), closeTo(total * (1 - f), 0.01));
      }
    });

    test('follows the great circle (bows towards the pole)', () {
      final LatLng mid = GeoMath.interpolate(london, newYork, 0.5);
      expect(mid.latitude, closeTo(52.36844, 1e-4));
      expect(mid.longitude, closeTo(-41.29031, 1e-4));
    });

    test('very short segments', () {
      const LatLng a = LatLng(41, 29);
      const LatLng b = LatLng(41.00001, 29.00001);
      final LatLng mid = GeoMath.interpolate(a, b, 0.5);
      expect(mid.latitude, closeTo(41.000005, 1e-9));
      expect(mid.longitude, closeTo(29.000005, 1e-9));
    });

    test('short segment across the antimeridian', () {
      final LatLng mid = GeoMath.interpolate(const LatLng(0, 179.99999), const LatLng(0, -179.99999), 0.5);
      expect(mid.longitude.abs(), closeTo(180, 1e-6));
    });
  });

  group('angles', () {
    test('normalizeAngle', () {
      expect(GeoMath.normalizeAngle(0), 0);
      expect(GeoMath.normalizeAngle(360), 0);
      expect(GeoMath.normalizeAngle(-90), 270);
      expect(GeoMath.normalizeAngle(725), 5);
    });

    test('shortestAngleDelta turns the short way', () {
      expect(GeoMath.shortestAngleDelta(359, 1), closeTo(2, 1e-9));
      expect(GeoMath.shortestAngleDelta(1, 359), closeTo(-2, 1e-9));
      expect(GeoMath.shortestAngleDelta(10, 190), 180);
      expect(GeoMath.shortestAngleDelta(90, 90), 0);
      expect(GeoMath.shortestAngleDelta(-170, 170), closeTo(-20, 1e-9));
    });

    test('lerpAngle crosses north the short way', () {
      expect(GeoMath.lerpAngle(359, 1, 0.5), closeTo(0, 1e-9));
      expect(GeoMath.lerpAngle(350, 20, 0.5), closeTo(5, 1e-9));
      expect(GeoMath.lerpAngle(20, 350, 0.5), closeTo(5, 1e-9));
      expect(GeoMath.lerpAngle(90, 180, 1), 180);
    });
  });
}
