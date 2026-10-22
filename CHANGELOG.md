## 0.1.1

* Fixed: the `bearing` passed to `animateTo` was overwritten on the next frame; it is now used for that fix.
* Fixed: `animateTo(..., duration: Duration.zero)` could produce an invalid (NaN) position; the marker is now
  placed at the new position at once.
* Fixed: a zero-length remaining line at the end of a route (and passed line at its start) was sent to the map.
* The travelled/remaining polylines are rebuilt only after the marker has moved
  `RoutePolylineStyle.refreshDistance` meters (default 2), not on every frame, so long routes no longer send every
  point to the map 60 times a second.
* README: "Works well with" section (google_maps_polyline, marker_crafter, advanced_background_locator,
  route_simulator), an advanced_background_locator example with the background isolate port, and the GIF
  placeholder removed. All README snippets were checked against the current APIs.
* Example: start/end points and a road guide line in the map-less preview, sharper heading arrow, no overflow of
  the progress text on narrow screens.

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

## 0.1.1 (Türkçe)

* Düzeltildi: `animateTo`'ya verilen `bearing` bir sonraki karede eziliyordu; artık o konum için kullanılıyor.
* Düzeltildi: `animateTo(..., duration: Duration.zero)` geçersiz (NaN) konum üretebiliyordu; marker artık yeni
  konuma hemen yerleşiyor.
* Düzeltildi: rota sonunda sıfır uzunlukta "kalan" (başında "geçilen") çizgi haritaya gönderiliyordu.
* Geçilen/kalan çizgiler her karede değil, marker `RoutePolylineStyle.refreshDistance` metre (varsayılan 2)
  ilerledikçe yenileniyor; uzun rotalar haritaya saniyede 60 kez tüm noktaları göndermiyor.
* README: "Birlikte kullanım" bölümü (google_maps_polyline, marker_crafter, advanced_background_locator,
  route_simulator), arka plan isolate'i ile advanced_background_locator örneği; GIF yer tutucusu kaldırıldı. README
  örnekleri güncel API'lerle derlenerek doğrulandı.
* Örnek: haritasız önizlemede başlangıç/bitiş noktaları ve yol kılavuz çizgisi, daha belirgin yön oku, dar ekranda
  taşmayan ilerleme metni.

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
