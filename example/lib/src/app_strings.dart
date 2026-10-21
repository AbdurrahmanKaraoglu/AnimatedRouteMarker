import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter/material.dart';

/// The app language chosen in the language menu; null follows the device.
final ValueNotifier<Locale?> appLocale = ValueNotifier<Locale?>(null);

const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('tr')];

/// Turkish on Turkish devices, English everywhere else.
Locale resolveLocale(List<Locale>? deviceLocales, Iterable<Locale> supported) {
  for (final Locale locale in deviceLocales ?? const <Locale>[]) {
    if (locale.languageCode == 'tr') {
      return const Locale('tr');
    }
    if (locale.languageCode == 'en') {
      return const Locale('en');
    }
  }
  return const Locale('en');
}

/// UI texts of the example. Every language implements every getter, so a
/// missing translation is a compile error.
abstract class AppStrings {
  const AppStrings();

  static AppStrings of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'tr' ? const _TurkishStrings() : const _EnglishStrings();

  String get navRoute;
  String get navLive;

  String get routeTitle;
  String get routeSubtitle;
  String get liveTitle;
  String get liveSubtitle;

  String get courier;
  String get taxi;
  String get truck;

  String get play;
  String get pause;
  String get stop;
  String get speed;
  String get followCamera;
  String get colorPassed;
  String get courierArrived;
  String status(RouteAnimationStatus status);

  String get startFeed;
  String get stopFeed;
  String get sendJump;
  String accepted(int count);
  String ignored(int count);
  String get lastFixAccepted;
  String get lastFixIgnored;

  String get noKeyTitle;
  String get noKeyBody;

  String get language;
  String get systemLanguage;

  String get decimalSeparator;

  /// "1.2 km" or "850 m".
  String distance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', decimalSeparator)} km';
  }

  /// "4 min 05 s".
  String duration(Duration value);
}

class _EnglishStrings extends AppStrings {
  const _EnglishStrings();

  @override
  String get navRoute => 'Route';
  @override
  String get navLive => 'Live';

  @override
  String get routeTitle => 'Route playback';
  @override
  String get routeSubtitle => 'Three vehicles on decoded routes';
  @override
  String get liveTitle => 'Live tracking';
  @override
  String get liveSubtitle =>
      'Simulated GPS: one fix per second with noise. Feed positions from advanced_background_locator or any '
      'location stream the same way.';

  @override
  String get courier => 'Courier';
  @override
  String get taxi => 'Taxi';
  @override
  String get truck => 'Truck';

  @override
  String get play => 'Play';
  @override
  String get pause => 'Pause';
  @override
  String get stop => 'Stop';
  @override
  String get speed => 'Speed';
  @override
  String get followCamera => 'Follow with camera';
  @override
  String get colorPassed => 'Color the travelled route';
  @override
  String get courierArrived => 'The courier has arrived.';
  @override
  String status(RouteAnimationStatus status) => switch (status) {
        RouteAnimationStatus.idle => 'Ready',
        RouteAnimationStatus.playing => 'Moving',
        RouteAnimationStatus.paused => 'Paused',
        RouteAnimationStatus.completed => 'Arrived',
      };

  @override
  String get startFeed => 'Start GPS';
  @override
  String get stopFeed => 'Stop GPS';
  @override
  String get sendJump => 'Send a GPS jump';
  @override
  String accepted(int count) => 'Accepted · $count';
  @override
  String ignored(int count) => 'Ignored · $count';
  @override
  String get lastFixAccepted => 'Last fix accepted';
  @override
  String get lastFixIgnored => 'Last fix ignored (noise or jump)';

  @override
  String get noKeyTitle => 'No Google Maps key';
  @override
  String get noKeyBody =>
      'Add MAPS_API_KEY to android/local.properties to see the map. Until then the same animation runs on a simple preview.';

  @override
  String get language => 'Language';
  @override
  String get systemLanguage => 'Device language';

  @override
  String get decimalSeparator => '.';

  @override
  String duration(Duration value) => '${value.inMinutes} min ${(value.inSeconds % 60).toString().padLeft(2, '0')} s';
}

class _TurkishStrings extends AppStrings {
  const _TurkishStrings();

  @override
  String get navRoute => 'Rota';
  @override
  String get navLive => 'Canlı';

  @override
  String get routeTitle => 'Rota oynatma';
  @override
  String get routeSubtitle => 'Çözülmüş rotalarda üç araç';
  @override
  String get liveTitle => 'Canlı takip';
  @override
  String get liveSubtitle =>
      'Simüle GPS: saniyede bir, gürültülü konum. advanced_background_locator ya da herhangi bir konum akışından '
      'gelen konumlar da aynı şekilde verilir.';

  @override
  String get courier => 'Kurye';
  @override
  String get taxi => 'Taksi';
  @override
  String get truck => 'Kamyon';

  @override
  String get play => 'Oynat';
  @override
  String get pause => 'Duraklat';
  @override
  String get stop => 'Durdur';
  @override
  String get speed => 'Hız';
  @override
  String get followCamera => 'Kamerayla takip et';
  @override
  String get colorPassed => 'Geçilen yolu renklendir';
  @override
  String get courierArrived => 'Kurye teslimat noktasına ulaştı.';
  @override
  String status(RouteAnimationStatus status) => switch (status) {
        RouteAnimationStatus.idle => 'Hazır',
        RouteAnimationStatus.playing => 'Hareket ediyor',
        RouteAnimationStatus.paused => 'Duraklatıldı',
        RouteAnimationStatus.completed => 'Vardı',
      };

  @override
  String get startFeed => 'GPS başlat';
  @override
  String get stopFeed => 'GPS durdur';
  @override
  String get sendJump => 'GPS sıçraması gönder';
  @override
  String accepted(int count) => 'Kabul · $count';
  @override
  String ignored(int count) => 'Yok sayılan · $count';
  @override
  String get lastFixAccepted => 'Son konum kabul edildi';
  @override
  String get lastFixIgnored => 'Son konum yok sayıldı (gürültü ya da sıçrama)';

  @override
  String get noKeyTitle => 'Google Maps anahtarı yok';
  @override
  String get noKeyBody =>
      'Haritayı görmek için android/local.properties dosyasına MAPS_API_KEY ekleyin. O zamana kadar aynı animasyon basit bir önizlemede çalışır.';

  @override
  String get language => 'Dil';
  @override
  String get systemLanguage => 'Cihaz dili';

  @override
  String get decimalSeparator => ',';

  @override
  String duration(Duration value) => '${value.inMinutes} dk ${(value.inSeconds % 60).toString().padLeft(2, '0')} sn';
}
