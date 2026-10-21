import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Owns three controllers like an app screen would.
class _Fleet extends StatefulWidget {
  const _Fleet({required this.onBuild});

  final void Function(Set<Marker> markers, Set<Polyline> polylines) onBuild;

  @override
  State<_Fleet> createState() => _FleetState();
}

class _FleetState extends State<_Fleet> with TickerProviderStateMixin {
  late final List<AnimatedRouteMarkerController> controllers = <AnimatedRouteMarkerController>[
    for (int i = 0; i < 3; i++)
      AnimatedRouteMarkerController(
        vsync: this,
        marker: Marker(markerId: MarkerId('vehicle$i')),
        polylineStyle: const RoutePolylineStyle(),
      )..setRoute(
          <LatLng>[LatLng(41 + i / 100, 29), LatLng(41 + i / 100, 29.01)],
          speed: 20.0 + i * 10,
          autoPlay: true,
        ),
  ];

  @override
  void dispose() {
    for (final AnimatedRouteMarkerController controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRouteMarkers(
      controllers: controllers,
      builder: (BuildContext context, Set<Marker> markers, Set<Polyline> polylines) {
        widget.onBuild(markers, polylines);
        return Text('${markers.length}', textDirection: TextDirection.ltr);
      },
    );
  }
}

void main() {
  testWidgets('rebuilds with every marker and polyline while they move', (WidgetTester tester) async {
    final List<Set<Marker>> builds = <Set<Marker>>[];
    Set<Polyline> lastPolylines = <Polyline>{};
    await tester.pumpWidget(_Fleet(onBuild: (Set<Marker> markers, Set<Polyline> polylines) {
      builds.add(markers);
      lastPolylines = polylines;
    }));
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(builds.length, greaterThanOrEqualTo(3));
    expect(
        builds.last.map((Marker m) => m.markerId.value), unorderedEquals(<String>['vehicle0', 'vehicle1', 'vehicle2']));
    // Different speeds: the markers have moved by different amounts.
    final Map<String, double> moved = <String, double>{
      for (final Marker m in builds.last) m.markerId.value: m.position.longitude,
    };
    expect(moved['vehicle2']! > moved['vehicle1']! && moved['vehicle1']! > moved['vehicle0']!, isTrue);
    expect(lastPolylines, hasLength(6));
  });

  testWidgets('disposing the screen mid-animation leaves no ticker running', (WidgetTester tester) async {
    await tester.pumpWidget(_Fleet(onBuild: (_, __) {}));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(const SizedBox());
    // TickerProviderStateMixin asserts if a ticker outlives the state; no
    // further frames are requested.
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('switches to a new controller list', (WidgetTester tester) async {
    final AnimatedRouteMarkerController a = AnimatedRouteMarkerController(
      vsync: const TestVSync(),
      marker: const Marker(markerId: MarkerId('a')),
    );
    final AnimatedRouteMarkerController b = AnimatedRouteMarkerController(
      vsync: const TestVSync(),
      marker: const Marker(markerId: MarkerId('b')),
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    Widget build(List<AnimatedRouteMarkerController> controllers) => AnimatedRouteMarkers(
          controllers: controllers,
          builder: (_, Set<Marker> markers, __) =>
              Text(markers.map((Marker m) => m.markerId.value).join(), textDirection: TextDirection.ltr),
        );

    await tester.pumpWidget(build(<AnimatedRouteMarkerController>[a]));
    expect(find.text('a'), findsOneWidget);
    await tester.pumpWidget(build(<AnimatedRouteMarkerController>[a, b]));
    expect(find.text('ab'), findsOneWidget);

    // Only the current list is listened to.
    b.jumpTo(const LatLng(1, 1));
    await tester.pump();
    expect(find.text('ab'), findsOneWidget);
  });
}
