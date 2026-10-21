import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_marker_controller.dart';

/// Builds a map from the markers and route lines of several controllers.
typedef AnimatedRouteMarkersBuilder = Widget Function(
  BuildContext context,
  Set<Marker> markers,
  Set<Polyline> polylines,
);

/// Rebuilds [builder] whenever any of [controllers] moves, with all their
/// markers and polylines. Use it around a `GoogleMap`:
///
/// ```dart
/// AnimatedRouteMarkers(
///   controllers: [courier, taxi],
///   builder: (context, markers, polylines) => GoogleMap(
///     initialCameraPosition: start,
///     markers: {...markers, ...staticMarkers},
///     polylines: polylines,
///   ),
/// )
/// ```
///
/// The widget does not own the controllers; dispose them yourself.
class AnimatedRouteMarkers extends StatefulWidget {
  const AnimatedRouteMarkers({super.key, required this.controllers, required this.builder});

  final List<AnimatedRouteMarkerController> controllers;

  final AnimatedRouteMarkersBuilder builder;

  @override
  State<AnimatedRouteMarkers> createState() => _AnimatedRouteMarkersState();
}

class _AnimatedRouteMarkersState extends State<AnimatedRouteMarkers> {
  late Listenable _listenable = Listenable.merge(widget.controllers);

  @override
  void didUpdateWidget(AnimatedRouteMarkers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.controllers, widget.controllers)) {
      _listenable = Listenable.merge(widget.controllers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (BuildContext context, _) => widget.builder(
        context,
        <Marker>{for (final AnimatedRouteMarkerController controller in widget.controllers) controller.marker},
        <Polyline>{for (final AnimatedRouteMarkerController controller in widget.controllers) ...controller.polylines},
      ),
    );
  }
}
