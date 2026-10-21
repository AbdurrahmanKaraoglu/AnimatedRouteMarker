import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marker_crafter/marker_crafter.dart';

/// Vehicle icons drawn with marker_crafter. The location marker's "antennas"
/// point up, so the icon faces north and needs no `rotationOffset`; use
/// `flat: true` and `anchor: Offset(0.5, 0.5)` so it turns around its center.
Future<BitmapDescriptor> vehicleIcon(Color color) => createLocationMarkerBitmap(color, size: 34);

/// Round "A" / "B" markers for the start and the end of a route.
Future<BitmapDescriptor> endpointIcon(String text, Color color) =>
    createRingMarkerBitmap(text, radius: 14, backgroundColor: color);
