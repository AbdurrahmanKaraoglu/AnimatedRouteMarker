import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'demo_data.dart';
import 'demo_map.dart';
import 'language_menu.dart';
import 'vehicle_icons.dart';

/// Three vehicles on fixed routes; the courier has playback controls.
class RoutePage extends StatefulWidget {
  const RoutePage({super.key, required this.hasMapsKey});

  final bool hasMapsKey;

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> with TickerProviderStateMixin {
  static const double _courierSpeed = 12;
  static const double _taxiSpeed = 14;
  static const double _truckSpeed = 9;

  static const RoutePolylineStyle _courierLine = RoutePolylineStyle(
    remainingColor: courierColor,
    passedColor: Color(0xFFA0AEC0),
    width: 6,
  );

  final List<LatLng> _courierRoute = decodeRoute(courierPolyline);

  late final AnimatedRouteMarkerController _courier = AnimatedRouteMarkerController(
    vsync: this,
    marker: _vehicleMarker('courier'),
    speed: _courierSpeed,
    polylineStyle: _courierLine,
    onCompleted: _onCourierArrived,
  )..setRoute(_courierRoute);

  late final AnimatedRouteMarkerController _taxi = AnimatedRouteMarkerController(
    vsync: this,
    marker: _vehicleMarker('taxi'),
    speed: _taxiSpeed,
    loop: true,
    polylineStyle: RoutePolylineStyle(remainingColor: taxiColor.withValues(alpha: 0.6), passedColor: null, width: 4),
  )..setRoute(taxiRoute, autoPlay: true);

  late final AnimatedRouteMarkerController _truck = AnimatedRouteMarkerController(
    vsync: this,
    marker: _vehicleMarker('truck'),
    speed: _truckSpeed,
    loop: true,
    polylineStyle: RoutePolylineStyle(remainingColor: truckColor.withValues(alpha: 0.6), passedColor: null, width: 4),
  )..setRoute(truckRoute, autoPlay: true);

  late final List<AnimatedRouteMarkerController> _controllers = <AnimatedRouteMarkerController>[
    _taxi,
    _truck,
    _courier,
  ];

  Set<Marker> _endpoints = <Marker>{};
  GoogleMapController? _mapController;
  bool _follow = false;
  bool _colorPassed = true;
  double _multiplier = 1;

  static Marker _vehicleMarker(String id) => Marker(
        markerId: MarkerId(id),
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      );

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    final List<BitmapDescriptor> icons = await Future.wait(<Future<BitmapDescriptor>>[
      vehicleIcon(courierColor),
      vehicleIcon(taxiColor),
      vehicleIcon(truckColor),
      endpointIcon('A', courierColor),
      endpointIcon('B', courierColor),
    ]);
    if (!mounted) {
      return;
    }
    _courier.markerTemplate = _courier.markerTemplate.copyWith(iconParam: icons[0]);
    _taxi.markerTemplate = _taxi.markerTemplate.copyWith(iconParam: icons[1]);
    _truck.markerTemplate = _truck.markerTemplate.copyWith(iconParam: icons[2]);
    setState(() {
      _endpoints = <Marker>{
        Marker(
          markerId: const MarkerId('start'),
          position: _courierRoute.first,
          icon: icons[3],
          anchor: const Offset(0.5, 0.5),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: _courierRoute.last,
          icon: icons[4],
          anchor: const Offset(0.5, 0.5),
        ),
      };
    });
  }

  @override
  void dispose() {
    for (final AnimatedRouteMarkerController controller in _controllers) {
      controller.dispose();
    }
    _mapController?.dispose();
    super.dispose();
  }

  void _onCourierArrived() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).courierArrived)));
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyFollow();
  }

  void _applyFollow() {
    final GoogleMapController? map = _mapController;
    if (_follow && map != null) {
      _courier.followCamera(map, zoom: 16);
    } else {
      _courier.stopFollowingCamera();
    }
  }

  void _setMultiplier(double value) {
    setState(() => _multiplier = value);
    _courier.speed = _courierSpeed * value;
    _taxi.speed = _taxiSpeed * value;
    _truck.speed = _truckSpeed * value;
  }

  void _togglePlay() {
    if (_courier.status == RouteAnimationStatus.playing) {
      _courier.pause();
    } else {
      _courier.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.routeTitle),
            Text(strings.routeSubtitle, style: text.bodySmall),
          ],
        ),
        actions: const <Widget>[LanguageMenu()],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            children: <Widget>[
              if (!widget.hasMapsKey) ...<Widget>[
                NoKeyNotice(title: strings.noKeyTitle, body: strings.noKeyBody),
                const SizedBox(height: Gap.sm),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DemoMap(
                    hasMapsKey: widget.hasMapsKey,
                    controllers: _controllers,
                    bounds: <LatLng>[..._courierRoute, ...taxiRoute, ...truckRoute],
                    colors: <MarkerId, Color>{
                      const MarkerId('courier'): courierColor,
                      const MarkerId('taxi'): taxiColor,
                      const MarkerId('truck'): truckColor,
                    },
                    staticMarkers: _endpoints,
                    onMapCreated: _onMapCreated,
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
              _controlPanel(strings, text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlPanel(AppStrings strings, TextTheme text) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
        child: ValueListenableBuilder<RouteProgress>(
          valueListenable: _courier,
          builder: (BuildContext context, RouteProgress progress, _) {
            final bool playing = progress.status == RouteAnimationStatus.playing;
            final Duration left = Duration(seconds: (progress.remainingDistance / _courier.speed).round());
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(radius: 6, backgroundColor: courierColor),
                    const SizedBox(width: Gap.sm),
                    Text(strings.courier, style: text.titleSmall),
                    const SizedBox(width: Gap.sm),
                    Chip(
                      label: Text(strings.status(progress.status)),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: scheme.secondaryContainer,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${strings.distance(progress.distance)} / ${strings.distance(progress.totalDistance)}'
                        ' · ${strings.duration(left)}',
                        style: text.bodySmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                Slider(value: progress.fraction, onChanged: _courier.seek),
                Row(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _togglePlay,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      label: Text(playing ? strings.pause : strings.play),
                    ),
                    const SizedBox(width: Gap.sm),
                    IconButton.outlined(
                      onPressed: _courier.stop,
                      tooltip: strings.stop,
                      icon: const Icon(Icons.stop),
                    ),
                    const SizedBox(width: Gap.sm),
                    // Shrinks on narrow phones instead of overflowing.
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SegmentedButton<double>(
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<double>>[
                              ButtonSegment<double>(value: 1, label: Text('1×')),
                              ButtonSegment<double>(value: 5, label: Text('5×')),
                              ButtonSegment<double>(value: 20, label: Text('20×')),
                            ],
                            selected: <double>{_multiplier},
                            onSelectionChanged: (Set<double> value) => _setMultiplier(value.single),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(strings.followCamera),
                  value: _follow,
                  onChanged: widget.hasMapsKey
                      ? (bool value) {
                          setState(() => _follow = value);
                          _applyFollow();
                        }
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(strings.colorPassed),
                  value: _colorPassed,
                  onChanged: (bool value) {
                    setState(() => _colorPassed = value);
                    _courier.polylineStyle = value
                        ? _courierLine
                        : const RoutePolylineStyle(remainingColor: courierColor, passedColor: courierColor, width: 6);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
