import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_polyline/google_maps_polyline.dart';

/// The courier's route (Karaköy → Yenikapı) as a Google encoded polyline, the
/// format the Directions API returns in `overview_polyline`. With an API key,
/// `GoogleMapsPolyline().getRouteBetweenCoordinates(...)` gives the same kind
/// of points for a real road route.
const String courierPolyline = r'wckyFgqzoDrIfJjHzJfJjHjC{OjCka@g@{TnF{OvQ?zYvGzTfJvLja@bGzm@kC~p@kM~iA';

/// Decodes [encoded] with google_maps_polyline and converts the points to
/// google_maps_flutter's [LatLng], the type animated_route_marker takes.
List<LatLng> decodeRoute(String encoded) => <LatLng>[
      for (final MyPointLatLng point in PolylineCodec.decode(encoded)) LatLng(point.latitude, point.longitude),
    ];

/// Taksim → Beşiktaş → Karaköy.
const List<LatLng> taxiRoute = <LatLng>[
  LatLng(41.0369, 28.9850),
  LatLng(41.0410, 28.9868),
  LatLng(41.0450, 28.9905),
  LatLng(41.0440, 28.9985),
  LatLng(41.0420, 29.0045),
  LatLng(41.0390, 28.9990),
  LatLng(41.0360, 28.9955),
  LatLng(41.0330, 28.9930),
  LatLng(41.0285, 28.9860),
  LatLng(41.0250, 28.9800),
  LatLng(41.0240, 28.9780),
];

/// Üsküdar → Harem → Kadıköy.
const List<LatLng> truckRoute = <LatLng>[
  LatLng(41.0262, 29.0145),
  LatLng(41.0215, 29.0110),
  LatLng(41.0165, 29.0095),
  LatLng(41.0120, 29.0105),
  LatLng(41.0060, 29.0160),
  LatLng(41.0000, 29.0215),
  LatLng(40.9945, 29.0245),
  LatLng(40.9910, 29.0250),
];

const Color courierColor = Color(0xFF1F3A5F);
const Color taxiColor = Color(0xFFB7791F);
const Color truckColor = Color(0xFF0F766E);

const CameraPosition istanbul = CameraPosition(target: LatLng(41.018, 28.993), zoom: 13.2);

const MethodChannel _config = MethodChannel('animated_route_marker_example/config');

/// Whether the Android build has a Google Maps key (MAPS_API_KEY in
/// android/local.properties). Other platforms report false, so the example
/// shows its map-less preview there.
Future<bool> hasMapsKey() async {
  try {
    return await _config.invokeMethod<bool>('hasMapsKey') ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
