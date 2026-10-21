import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'demo_data.dart';
import 'route_sketch.dart';

/// A Google Map with the animated markers, or the [RouteSketch] preview when
/// the build has no Maps key.
class DemoMap extends StatelessWidget {
  const DemoMap({
    super.key,
    required this.hasMapsKey,
    required this.controllers,
    required this.bounds,
    required this.colors,
    this.staticMarkers = const <Marker>{},
    this.onMapCreated,
  });

  final bool hasMapsKey;
  final List<AnimatedRouteMarkerController> controllers;
  final List<LatLng> bounds;
  final Map<MarkerId, Color> colors;
  final Set<Marker> staticMarkers;
  final MapCreatedCallback? onMapCreated;

  @override
  Widget build(BuildContext context) {
    return AnimatedRouteMarkers(
      controllers: controllers,
      builder: (BuildContext context, Set<Marker> markers, Set<Polyline> polylines) {
        final Set<Marker> all = <Marker>{...staticMarkers, ...markers};
        if (!hasMapsKey) {
          return RouteSketch(bounds: bounds, markers: all, polylines: polylines, colors: colors);
        }
        return GoogleMap(
          initialCameraPosition: istanbul,
          markers: all,
          polylines: polylines,
          onMapCreated: onMapCreated,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        );
      },
    );
  }
}

/// Explains how to add a Maps key; shown above the preview.
class NoKeyNotice extends StatelessWidget {
  const NoKeyNotice({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.key_off_outlined, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: text.titleSmall?.copyWith(color: scheme.onTertiaryContainer)),
                  const SizedBox(height: 2),
                  Text(body, style: text.bodySmall?.copyWith(color: scheme.onTertiaryContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
