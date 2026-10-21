## 0.1.0

* First release.
* `AnimatedRouteMarkerController`: moves a marker along a `List<LatLng>` at a speed in m/s or over a duration,
  with great-circle distance, bearing and interpolation, and heading easing that turns the short way.
* Live mode (`animateTo`, `jumpTo`) with a minimum move distance against GPS noise and a confirmed-jump filter.
* `play`, `pause`, `seek`, `seekToDistance`, `stop`, `loop`, `onCompleted`, progress as `ValueListenable` and
  `Stream`.
* Camera follow (`followCamera`) with optional zoom, tilt and rotation.
* Optional travelled/remaining polylines (`RoutePolylineStyle`).
* `AnimatedRouteMarkers` widget for several markers on one map.
* `GeoMath` and `RoutePath` geometry helpers.
* Example app in English and Turkish.

---

## 0.1.0 (Türkçe)

* İlk sürüm.
* `AnimatedRouteMarkerController`: marker'ı bir `List<LatLng>` boyunca m/s cinsinden hızla ya da toplam sürede
  hareket ettirir; büyük daire mesafesi, yön ve interpolasyon; kısa yoldan dönen yumuşak yön geçişi.
* Canlı mod (`animateTo`, `jumpTo`): GPS gürültüsüne karşı en küçük hareket mesafesi ve doğrulanmış sıçrama filtresi.
* `play`, `pause`, `seek`, `seekToDistance`, `stop`, `loop`, `onCompleted`; `ValueListenable` ve `Stream` ile
  ilerleme.
* Kamera takibi (`followCamera`): isteğe bağlı yakınlaştırma, eğim ve döndürme.
* İsteğe bağlı geçilen/kalan rota çizgileri (`RoutePolylineStyle`).
* Tek haritada birden fazla marker için `AnimatedRouteMarkers` widget'ı.
* `GeoMath` ve `RoutePath` geometri yardımcıları.
* Türkçe ve İngilizce örnek uygulama.
