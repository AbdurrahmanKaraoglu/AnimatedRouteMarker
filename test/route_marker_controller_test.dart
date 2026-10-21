import 'dart:math' as math;

import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A point [meters] from [origin] towards [bearing] (flat approximation,
/// fine for the short distances used here).
LatLng offset(LatLng origin, double meters, double bearing) {
  final double rad = bearing * math.pi / 180;
  final double dLat = meters * math.cos(rad) / 111195.08;
  final double dLng = meters * math.sin(rad) / (111195.08 * math.cos(origin.latitude * math.pi / 180));
  return LatLng(origin.latitude + dLat, origin.longitude + dLng);
}

void main() {
  const LatLng start = LatLng(41.0, 29.0);
  final LatLng north100 = offset(start, 100, 0);
  final LatLng east100 = offset(north100, 100, 90);

  AnimatedRouteMarkerController create({
    double speed = 10,
    Duration rotationDuration = const Duration(milliseconds: 300),
    RoutePolylineStyle? polylineStyle,
    double rotationOffset = 0,
  }) {
    return AnimatedRouteMarkerController(
      vsync: const TestVSync(),
      marker: const Marker(markerId: MarkerId('car'), flat: true, anchor: Offset(0.5, 0.5)),
      speed: speed,
      rotationDuration: rotationDuration,
      polylineStyle: polylineStyle,
      rotationOffset: rotationOffset,
    );
  }

  testWidgets('setRoute places the marker at the start, facing the route', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100, east100]);

    expect(controller.marker.position, start);
    expect(controller.value.bearing, closeTo(0, 0.01));
    expect(controller.value.totalDistance, closeTo(200, 0.5));
    expect(controller.status, RouteAnimationStatus.idle);
    expect(controller.marker.markerId, const MarkerId('car'));
    expect(controller.marker.flat, isTrue);
  });

  testWidgets('moves at the given speed in meters per second', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100, east100], speed: 10, autoPlay: true);

    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(controller.value.distance, closeTo(50, 1e-6));
    expect(GeoMath.distance(start, controller.marker.position), closeTo(50, 0.01));
    expect(controller.status, RouteAnimationStatus.playing);

    await tester.pump(const Duration(seconds: 10));
    expect(controller.value.distance, closeTo(150, 1e-6));
    expect(controller.value.segmentIndex, 1);
    expect(controller.value.fraction, closeTo(0.75, 0.01));
    controller.stop();
  });

  testWidgets('duration mode completes on time and calls onCompleted once', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    int completed = 0;
    controller.onCompleted = () => completed++;
    controller.setRoute(<LatLng>[start, north100, east100], duration: const Duration(seconds: 20), autoPlay: true);

    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(controller.value.fraction, closeTo(0.5, 1e-6));
    await tester.pump(const Duration(seconds: 10));
    expect(controller.status, RouteAnimationStatus.completed);
    expect(controller.marker.position, east100);
    expect(completed, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(completed, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('pause, play, seek and stop', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100, east100], speed: 10, autoPlay: true);

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    controller.pause();
    final double paused = controller.value.distance;
    expect(controller.status, RouteAnimationStatus.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.value.distance, paused);

    controller.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.value.distance, closeTo(paused + 10, 1e-6));

    controller.seek(0.5);
    expect(controller.value.distance, closeTo(controller.value.totalDistance / 2, 1e-6));
    expect(controller.status, RouteAnimationStatus.playing);

    controller.seek(1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.status, RouteAnimationStatus.completed);

    controller.seek(0.25);
    expect(controller.status, RouteAnimationStatus.paused);

    controller.stop();
    expect(controller.status, RouteAnimationStatus.idle);
    expect(controller.marker.position, start);
    expect(controller.value.distance, 0);
  });

  testWidgets('play after completion starts over; loop repeats', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100], speed: 50, autoPlay: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.status, RouteAnimationStatus.completed);

    controller.play();
    expect(controller.value.distance, 0);
    controller.loop = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.status, RouteAnimationStatus.playing);
    controller.pause();
  });

  testWidgets('play before a route throws', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    expect(controller.play, throwsStateError);
    expect(() => controller.setRoute(const <LatLng>[]), throwsArgumentError);
  });

  testWidgets('turns the short way across north', (WidgetTester tester) async {
    // Heading 350°, then 10°: the marker must turn 20° through north,
    // never the long way round through south.
    final LatLng a = offset(start, 50, 350);
    final LatLng b = offset(a, 50, 10);
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, a, b], speed: 10, autoPlay: true);
    expect(controller.value.bearing, closeTo(350, 0.1));

    await tester.pump();
    final List<double> headings = <double>[];
    for (int i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      headings.add(controller.value.bearing);
    }
    for (final double heading in headings) {
      expect(heading >= 349.9 || heading <= 10.1, isTrue, reason: 'heading $heading');
    }
    // Eased, not snapped: some frames are between the two headings.
    expect(headings.where((double h) => h > 351 || h < 9), isNotEmpty);
    expect(controller.value.bearing, closeTo(10, 0.5));
    controller.stop();
  });

  testWidgets('rotationOffset turns the drawn marker only', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create(rotationOffset: -90);
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, offset(start, 100, 90)]);
    expect(controller.value.bearing, closeTo(90, 0.1));
    expect(GeoMath.shortestAngleDelta(controller.marker.rotation, 0), closeTo(0, 0.1));
  });

  group('live mode', () {
    testWidgets('first position is placed directly', (WidgetTester tester) async {
      final AnimatedRouteMarkerController controller = create();
      addTearDown(controller.dispose);
      expect(controller.animateTo(start), isTrue);
      expect(controller.mode, RouteAnimationMode.live);
      expect(controller.marker.position, start);
    });

    testWidgets('interpolates towards new positions without jumps', (WidgetTester tester) async {
      final AnimatedRouteMarkerController controller = create();
      addTearDown(controller.dispose);
      controller.animateTo(start);

      expect(controller.animateTo(north100, duration: const Duration(seconds: 2)), isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(GeoMath.distance(start, controller.marker.position), closeTo(50, 0.1));
      expect(controller.value.bearing, closeTo(0, 0.1));

      // A new position mid-way continues from where the marker is.
      final LatLng before = controller.marker.position;
      controller.animateTo(east100, duration: const Duration(seconds: 1));
      expect(controller.marker.position, before);
      await tester.pump(const Duration(milliseconds: 500));
      expect(GeoMath.distance(before, controller.marker.position), closeTo(GeoMath.distance(before, east100) / 2, 0.1));

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.marker.position, east100);
      expect(controller.status, RouteAnimationStatus.completed);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('ignores GPS noise below minMoveDistance', (WidgetTester tester) async {
      final AnimatedRouteMarkerController controller = create()..minMoveDistance = 3;
      addTearDown(controller.dispose);
      controller.animateTo(start);
      expect(controller.animateTo(offset(start, 2, 180)), isFalse);
      expect(controller.marker.position, start);
      expect(controller.status, RouteAnimationStatus.completed);
    });

    testWidgets('a single GPS jump is ignored, a confirmed one is applied', (WidgetTester tester) async {
      final AnimatedRouteMarkerController controller = create()..jumpDistance = 500;
      addTearDown(controller.dispose);
      controller.animateTo(start);

      final LatLng far = offset(start, 5000, 45);
      expect(controller.animateTo(far), isFalse);
      expect(controller.marker.position, start);

      // A normal fix after the spike clears it.
      expect(controller.animateTo(north100, duration: Duration.zero), isTrue);
      expect(controller.animateTo(far), isFalse);

      // Two consecutive fixes agree: the marker moves there at once.
      expect(controller.animateTo(offset(far, 20, 0)), isTrue);
      expect(controller.marker.position, offset(far, 20, 0));
      await tester.pump();
    });

    testWidgets('paused live mode waits for play', (WidgetTester tester) async {
      final AnimatedRouteMarkerController controller = create();
      addTearDown(controller.dispose);
      controller.animateTo(start);
      controller.animateTo(north100, duration: const Duration(seconds: 2));
      await tester.pump();
      controller.pause();
      controller.animateTo(east100);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.status, RouteAnimationStatus.paused);
      controller.play();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(controller.marker.position, east100);
    });
  });

  testWidgets('publishes progress as ValueListenable and Stream', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    final List<RouteProgress> streamed = <RouteProgress>[];
    controller.progressStream.listen(streamed.add);
    int notified = 0;
    controller.addListener(() => notified++);

    controller.setRoute(<LatLng>[start, north100], speed: 50, autoPlay: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(notified, greaterThanOrEqualTo(3));
    expect(streamed, isNotEmpty);
    expect(streamed.last.status, RouteAnimationStatus.completed);
    expect(streamed.last.fraction, 1);
    expect(controller.value.remainingDistance, 0);
  });

  testWidgets('polylines split into passed and remaining parts', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create(polylineStyle: const RoutePolylineStyle());
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100, east100]);
    controller.seek(0.75);

    final Map<String, Polyline> lines = <String, Polyline>{
      for (final Polyline line in controller.polylines) line.polylineId.value: line,
    };
    expect(lines.keys, unorderedEquals(<String>['car#passed', 'car#remaining']));
    expect(lines['car#passed']!.points.first, start);
    expect(lines['car#passed']!.points.last, controller.marker.position);
    expect(lines['car#remaining']!.points.first, controller.marker.position);
    expect(lines['car#remaining']!.points.last, east100);

    controller.polylineStyle = const RoutePolylineStyle(passedColor: null);
    controller.seek(0.5);
    expect(controller.polylines.map((Polyline l) => l.polylineId.value), <String>['car#remaining']);

    controller.polylineStyle = null;
    controller.seek(0.2);
    expect(controller.polylines, isEmpty);
  });

  testWidgets('camera follows the marker, one move at a time', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100], speed: 10, autoPlay: true);

    final List<CameraUpdate> moves = <CameraUpdate>[];
    Future<void> pending = Future<void>.value();
    controller.followCameraWith((CameraUpdate update) {
      moves.add(update);
      return pending;
    });
    expect(controller.isFollowingCamera, isTrue);
    expect(moves, hasLength(1));
    await tester.pump();
    expect(moves, hasLength(2));

    // While a move is still running, frames are merged into one later move.
    pending = Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    final int afterSlowMove = moves.length;
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(moves.length, afterSlowMove);
    await tester.pump(const Duration(seconds: 1));
    expect(moves.length, inInclusiveRange(afterSlowMove + 1, afterSlowMove + 2));

    controller.stopFollowingCamera();
    final int stopped = moves.length;
    await tester.pump(const Duration(seconds: 2));
    expect(moves.length, stopped);
    controller.pause();
  });

  testWidgets('markerTemplate changes the icon and keeps the position', (WidgetTester tester) async {
    final AnimatedRouteMarkerController controller = create();
    addTearDown(controller.dispose);
    controller.setRoute(<LatLng>[start, north100]);
    controller.seek(0.5);
    final LatLng position = controller.marker.position;
    controller.markerTemplate = controller.markerTemplate.copyWith(alphaParam: 0.5);
    expect(controller.marker.alpha, 0.5);
    expect(controller.marker.position, position);
  });
}
