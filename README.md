# animated_route_marker

[![pub package](https://img.shields.io/pub/v/animated_route_marker.svg)](https://pub.dev/packages/animated_route_marker)

Moves a [`google_maps_flutter`](https://pub.dev/packages/google_maps_flutter) marker (courier, taxi, truck, …)
smoothly along a route at a real speed, or towards live GPS positions, and turns it towards the direction of
travel without sudden spins.

*[Türkçe açıklama aşağıda.](#türkçe)*

## Features

- **Route playback** at a constant speed in m/s, or over a total duration. Distances and headings are computed on
  the great circle (haversine, initial bearing, spherical interpolation), so long segments and the antimeridian
  work too.
- **Smooth heading**: the marker eases into new headings and always turns the short way (359° → 1° is a 2° turn).
- **Live mode**: `animateTo(position)` glides from where the marker is to each new location fix. A fix that
  arrives mid-way continues from the current point. GPS noise below a threshold is ignored, and a single far-off
  "jump" is ignored until consecutive fixes confirm it.
- **Controls**: `play`, `pause`, `seek`, `seekToDistance`, `stop`, `loop`, changing `speed` while moving, an
  `onCompleted` callback, progress as a `ValueListenable<RouteProgress>` and as a `Stream<RouteProgress>`.
- **Camera follow**: keep the map centered on the marker, optionally with zoom, tilt and map rotation.
- **Travelled route in a different color** (optional): the route is split into a passed and a remaining polyline,
  rebuilt every few meters rather than on every frame, so long routes do not flood the map with updates.
- **Many markers at once**: one controller per marker, one `AnimatedRouteMarkers` widget for all of them.
- **No leaks**: each controller uses a `Ticker` from the `vsync` you pass (like `AnimationController`) and
  releases it in `dispose`. Tests check that disposing a screen mid-animation leaves no ticker running.
- **Plain inputs**: the API takes `List<LatLng>`, so routes can come from any source (Directions API,
  your backend, GPX, a recorded trip) and icons from any `BitmapDescriptor`.

## How it differs from existing packages

Checked on pub.dev on 22 October 2026:

| Package | What it does | What is missing for route animation |
|---|---|---|
| `flutter_animarker` 3.2.0 | Animates a marker through a list of positions, with rotation and ripple | Last release April 2021, repository inactive since early 2024; open issues about markers no longer animating and rotation taking the long way past 180° |
| `animated_marker` 0.3.2 | Animates position and rotation changes between two states | No route, speed, play/pause/seek or camera follow |
| `marker_motion` 0.2.0 | Animates between two positions by marker id | Its README lists rotation, polyline snapping and a minimum-distance threshold as not done yet |
| `google_map_animation` 0.0.2 | Draws polylines progressively, fades markers in | Marker movement is not tied to a route or a speed |

`animated_route_marker` is built for the courier/taxi case: a speed in meters per second, shortest-way heading
easing, a GPS jump filter for live data, playback controls, camera follow and a travelled/remaining route split,
for several markers at once.

## Installation

```yaml
dependencies:
  animated_route_marker: ^0.1.1
  google_maps_flutter: ^2.13.0
```

## Usage

### Moving along a route

```dart
import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CourierMap extends StatefulWidget {
  const CourierMap({super.key, required this.route});

  final List<LatLng> route;

  @override
  State<CourierMap> createState() => _CourierMapState();
}

class _CourierMapState extends State<CourierMap> with TickerProviderStateMixin {
  late final AnimatedRouteMarkerController courier = AnimatedRouteMarkerController(
    vsync: this,
    // Icon, anchor, callbacks…: everything except position and rotation is kept.
    marker: const Marker(markerId: MarkerId('courier'), flat: true, anchor: Offset(0.5, 0.5)),
    polylineStyle: const RoutePolylineStyle(), // optional: passed part in grey
    onCompleted: () => debugPrint('Arrived'),
  )..setRoute(widget.route, speed: 12, autoPlay: true); // 12 m/s ≈ 43 km/h

  @override
  void dispose() {
    courier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRouteMarkers(
      controllers: [courier],
      builder: (context, markers, polylines) => GoogleMap(
        initialCameraPosition: CameraPosition(target: widget.route.first, zoom: 15),
        markers: markers,
        polylines: polylines,
      ),
    );
  }
}
```

Use `flat: true` and `anchor: Offset(0.5, 0.5)` so the icon turns around its center and with the map. If your icon
does not point north, set `rotationOffset` (for an icon pointing east: `-90`).

Instead of a speed you can give the trip duration: `setRoute(points, duration: Duration(minutes: 3))`.

### Controls and progress

```dart
courier.play();
courier.pause();
courier.seek(0.5);              // half way
courier.seekToDistance(1200);   // 1.2 km from the start
courier.stop();                 // back to the start
courier.speed = 25;             // m/s, also while moving
courier.loop = true;

ValueListenableBuilder<RouteProgress>(
  valueListenable: courier,
  builder: (context, progress, _) => Slider(value: progress.fraction, onChanged: courier.seek),
);

courier.progressStream.listen((p) => print('${p.distance} / ${p.totalDistance} m, ${p.status}'));
```

`RouteProgress` holds the `position`, the displayed `bearing`, `distance`, `totalDistance`, `remainingDistance`,
`fraction`, `segmentIndex`, `status` (`idle`, `playing`, `paused`, `completed`) and `mode` (`route`, `live`).

### Live positions

Call `animateTo` whenever a new location arrives, from any location stream:

```dart
final vehicle = AnimatedRouteMarkerController(
  vsync: this,
  marker: const Marker(markerId: MarkerId('taxi'), flat: true, anchor: Offset(0.5, 0.5)),
  liveDuration: const Duration(seconds: 1), // ≈ your location update interval
  minMoveDistance: 2,   // ignore GPS noise below 2 m (no jitter or spinning while parked)
  jumpDistance: 500,    // a fix > 500 m away is a GPS jump…
  jumpConfirmations: 2, // …applied only when 2 consecutive fixes agree
);

locationStream.listen((location) {
  final accepted = vehicle.animateTo(LatLng(location.latitude, location.longitude));
  // accepted == false: ignored as noise or as an unconfirmed jump.
});
```

The first position places the marker directly; later ones are interpolated from the current point. Pass
`duration:` to override `liveDuration` for one fix (`Duration.zero` places it at once), and `bearing:` to use the
heading reported by the GPS instead of the direction between two fixes. Use `jumpTo(position)` to place the marker
without animation.

### Camera follow

```dart
GoogleMap(
  initialCameraPosition: start,
  onMapCreated: (map) => courier.followCamera(map, zoom: 16),
);
// Navigation style: tilted, map turns with the marker.
courier.followCamera(map, zoom: 17, tilt: 45, rotate: true);
courier.stopFollowingCamera();
```

Without `zoom`, `tilt` and `rotate`, only the camera target changes and the user keeps their zoom. Camera moves are
sent one at a time; frames that arrive while the map is busy are merged.

### Several markers

Create one controller per vehicle (all with the same `vsync` from a `TickerProviderStateMixin`) and pass them all
to `AnimatedRouteMarkers`; the map is rebuilt once per frame however many markers move. Add your static markers in
the builder: `markers: {...markers, ...myMarkers}`. Dispose every controller in your state's `dispose`.

## Works well with

animated_route_marker depends only on `google_maps_flutter`. These packages by the same author fit around it
(none of them is a dependency):

| Package | Use with animated_route_marker |
|---|---|
| [google_maps_polyline](https://pub.dev/packages/google_maps_polyline) | Get a route from the Directions API or decode an encoded polyline → `setRoute` |
| [marker_crafter](https://pub.dev/packages/marker_crafter) | Draw the vehicle icon on a canvas → `markerTemplate` |
| [advanced_background_locator](https://pub.dev/packages/advanced_background_locator) | Real device locations, also in the background → `animateTo` |
| [route_simulator](https://pub.dev/packages/route_simulator) | Realistic fake GPS along a route for demos and tests → `animateTo` |

Also by the same author: [advanced_geofence](https://pub.dev/packages/advanced_geofence),
[turkish_kit](https://pub.dev/packages/turkish_kit) and [flutter_toastify](https://pub.dev/packages/flutter_toastify).

### Routes from google_maps_polyline, icons from marker_crafter

See `example/` for a complete app:

```dart
import 'package:google_maps_polyline/google_maps_polyline.dart';
import 'package:marker_crafter/marker_crafter.dart';

// Route: from the Directions API, or decode an encoded polyline.
final result = await GoogleMapsPolyline().getRouteBetweenCoordinates(
  apiKey,
  const MyPointLatLng(41.0222, 28.9770),
  const MyPointLatLng(41.0035, 28.9500),
);
final route = [for (final p in result.points) LatLng(p.latitude, p.longitude)];
// or: PolylineCodec.decode(encoded)

// Icon: a canvas-drawn marker that points north.
final icon = await createLocationMarkerBitmap(Colors.indigo, size: 34);
courier.markerTemplate = courier.markerTemplate.copyWith(iconParam: icon);
courier.setRoute(route, speed: 12, autoPlay: true);
```

### Locations from advanced_background_locator

Its callbacks run in a background isolate, so send each location to the UI isolate through a port:

```dart
import 'dart:isolate';
import 'dart:ui';

import 'package:advanced_background_locator/advanced_background_locator.dart';

const String locationPortName = 'animated_route_marker_locations';

@pragma('vm:entry-point')
void onLocation(LocationDto location) {
  IsolateNameServer.lookupPortByName(locationPortName)?.send(<double>[location.latitude, location.longitude]);
}

// In your State (next to the controller):
final ReceivePort port = ReceivePort();

void listenToLocations() {
  IsolateNameServer.removePortNameMapping(locationPortName);
  IsolateNameServer.registerPortWithName(port.sendPort, locationPortName);
  port.listen((dynamic data) {
    final List<double> latLng = (data as List<dynamic>).cast<double>();
    vehicle.animateTo(LatLng(latLng[0], latLng[1]));
  });
}
// Register `onLocation` with AdvancedBackgroundLocator.registerLocationUpdate (see its README), and in dispose:
// port.close(); IsolateNameServer.removePortNameMapping(locationPortName);
```

Set `liveDuration` to the locator's update interval (`AndroidSettings.interval`).

### Simulated GPS from route_simulator

```dart
import 'package:route_simulator/route_simulator.dart';

final simulator = RouteSimulator(
  route: SimRoute.fromEncodedPolyline(encoded),
  profile: const SpeedProfile.realistic(cruiseSpeed: 50 / 3.6),
  noise: const GpsNoise(horizontalError: 4, seed: 42),
);
simulator.locations.listen((l) => vehicle.animateTo(LatLng(l.latitude, l.longitude)));
simulator.start();
```

### Geometry helpers

`GeoMath.distance`, `GeoMath.bearing`, `GeoMath.interpolate`, `GeoMath.shortestAngleDelta` and
`GeoMath.lerpAngle` are pure functions; `RoutePath` gives the length of a polyline and the point and heading at
any distance along it.

## Example app

`example/` shows three vehicles on decoded routes with playback controls, and a live tab fed by a simulated GPS
with noise and a "GPS jump" button. It is in English and Turkish.

The Google Maps key is read from `MAPS_API_KEY` in `example/android/local.properties` (not committed):

```properties
MAPS_API_KEY=your-key
```

Without a key the example still opens and runs the same animation on a simple map-less preview.

## License

MIT

---

## Türkçe

`google_maps_flutter` üzerindeki bir marker'ı (kurye, taksi, kamyon…) bir rota boyunca gerçek hızla ya da canlı GPS
konumlarına doğru akıcı biçimde hareket ettirir ve yönünü ani dönüşler olmadan hareket yönüne çevirir.

**Özellikler**

- **Rota oynatma**: sabit hız (m/s) ya da toplam süre ile. Mesafe ve yön büyük daire üzerinde hesaplanır
  (haversine, başlangıç yönü, küresel interpolasyon).
- **Yumuşak dönüş**: marker yeni yöne kademeli döner ve her zaman kısa yoldan döner (359° → 1° = 2°).
- **Canlı mod**: `animateTo(konum)` her yeni konumda mevcut noktadan yenisine kayar. Eşik altındaki GPS gürültüsü
  yok sayılır; tek bir uzak "sıçrama" ardışık konumlarla doğrulanana kadar uygulanmaz.
- **Kontrol**: `play`, `pause`, `seek`, `seekToDistance`, `stop`, `loop`, hareket halindeyken `speed` değişimi,
  `onCompleted`, `ValueListenable<RouteProgress>` ve `Stream<RouteProgress>` ile ilerleme.
- **Kamera kilidi**: `followCamera(map, zoom: 16)`; isteğe bağlı eğim ve haritanın marker ile dönmesi.
- **Geçilen yol farklı renkte** (isteğe bağlı) ve **aynı anda birden fazla marker** (`AnimatedRouteMarkers`).
- **Sızıntı yok**: her controller verdiğiniz `vsync`'ten bir `Ticker` alır ve `dispose`'da bırakır.
- Geçilen/kalan çizgiler her karede değil birkaç metrede bir yenilenir (`RoutePolylineStyle.refreshDistance`);
  uzun rotalar haritaya gereksiz yük bindirmez.
- Çekirdek API `List<LatLng>` alır; tek bağımlılık `google_maps_flutter`.

**Mevcut paketlerden farkı** (22 Ekim 2026'da pub.dev'de incelendi): `flutter_animarker` Nisan 2021'den beri
güncellenmiyor ve açık hata kayıtları var (animasyonun durması, 180°'de uzun yoldan dönme). `animated_marker` ve
`marker_motion` iki konum arasında animasyon yapar; rota, hız (m/s), oynat/duraklat/ileri sar ve kamera takibi yok.
`animated_route_marker` kurye/taksi senaryosu için hız, kısa yoldan dönüş, GPS sıçrama filtresi, oynatma
kontrolleri, kamera kilidi ve geçilen/kalan rota ayrımını birlikte sunar.

**Kısa kullanım**

```dart
final kurye = AnimatedRouteMarkerController(
  vsync: this, // TickerProviderStateMixin
  marker: const Marker(markerId: MarkerId('kurye'), flat: true, anchor: Offset(0.5, 0.5)),
  polylineStyle: const RoutePolylineStyle(),
  onCompleted: () => debugPrint('Vardı'),
)..setRoute(rota, speed: 12, autoPlay: true);

AnimatedRouteMarkers(
  controllers: [kurye],
  builder: (context, markers, polylines) => GoogleMap(
    initialCameraPosition: baslangic,
    markers: markers,
    polylines: polylines,
  ),
);

// Canlı konum (GPS'in bildirdiği yön varsa `bearing:` ile verilebilir):
konumAkisi.listen((k) => kurye.animateTo(LatLng(k.latitude, k.longitude)));

// dispose içinde:
kurye.dispose();
```

**Birlikte kullanım** (hiçbiri bağımlılık değildir):

- [google_maps_polyline](https://pub.dev/packages/google_maps_polyline): Directions API'den rota alır ya da
  kodlanmış polyline'ı çözer → `setRoute`.
- [marker_crafter](https://pub.dev/packages/marker_crafter): araç ikonunu Canvas ile çizer → `markerTemplate`.
- [advanced_background_locator](https://pub.dev/packages/advanced_background_locator): arka planda da gerçek
  konum → `animateTo`. Geri çağrılar ayrı bir isolate'te çalışır; konumu `IsolateNameServer` ile arayüze gönderin
  (yukarıdaki İngilizce örnek).
- [route_simulator](https://pub.dev/packages/route_simulator): rota boyunca gerçekçi sahte GPS, demo ve test için
  → `animateTo`.

Aynı geliştiricinin diğer paketleri: [advanced_geofence](https://pub.dev/packages/advanced_geofence),
[turkish_kit](https://pub.dev/packages/turkish_kit), [flutter_toastify](https://pub.dev/packages/flutter_toastify).

**Örnek uygulama**: `example/` Türkçe ve İngilizcedir. Harita anahtarı `example/android/local.properties`
dosyasındaki `MAPS_API_KEY` değerinden okunur; anahtar yoksa uygulama çökmez ve aynı animasyonu haritasız bir
önizlemede gösterir.

## Lisans

MIT
