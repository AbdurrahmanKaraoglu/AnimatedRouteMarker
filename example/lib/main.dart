import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_strings.dart';
import 'src/app_theme.dart';
import 'src/demo_data.dart';
import 'src/live_page.dart';
import 'src/route_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Without a key the example shows a map-less preview instead of the map.
  final bool mapsKey = await hasMapsKey();
  runApp(AnimatedRouteMarkerExampleApp(hasMapsKey: mapsKey));
}

class AnimatedRouteMarkerExampleApp extends StatelessWidget {
  const AnimatedRouteMarkerExampleApp({super.key, required this.hasMapsKey});

  final bool hasMapsKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocale,
      builder: (BuildContext context, Locale? locale, _) => MaterialApp(
        title: 'Animated Route Marker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Null follows the device language (Turkish or English).
        locale: locale,
        supportedLocales: supportedLocales,
        localeListResolutionCallback: resolveLocale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeShell(hasMapsKey: hasMapsKey),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.hasMapsKey});

  final bool hasMapsKey;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Scaffold(
      // Keeps both pages alive so the maps are not recreated on every switch.
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          RoutePage(hasMapsKey: widget.hasMapsKey),
          LivePage(hasMapsKey: widget.hasMapsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int index) => setState(() => _index = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: strings.navRoute,
          ),
          NavigationDestination(
            icon: const Icon(Icons.gps_not_fixed),
            selectedIcon: const Icon(Icons.gps_fixed),
            label: strings.navLive,
          ),
        ],
      ),
    );
  }
}
