# animated_route_marker example

English and Turkish demo of [animated_route_marker](https://pub.dev/packages/animated_route_marker):

- **Route** tab: a courier, a taxi and a truck on routes (the courier's is an encoded polyline decoded with
  `google_maps_polyline`), vehicle icons drawn with `marker_crafter`, play/pause/stop, seek slider, speed,
  camera follow and travelled-route color.
- **Live** tab: a simulated GPS sends one noisy fix per second; a button sends a GPS jump to show the filter.

Put your Google Maps key in `android/local.properties` (git-ignored):

```properties
MAPS_API_KEY=your-key
```

Without a key the app still starts and shows the animation on a map-less preview. Only Android is set up.
