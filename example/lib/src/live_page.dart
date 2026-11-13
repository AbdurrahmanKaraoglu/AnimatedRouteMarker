import 'dart:async';
import 'dart:math' as math;

import 'package:animated_route_marker/animated_route_marker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_strings.dart';
import 'app_theme.dart';
import 'demo_data.dart';
import 'demo_map.dart';
import 'language_menu.dart';
import 'vehicle_icons.dart';

/// Live mode: a simulated GPS sends one noisy fix per second and the marker
/// glides from fix to fix.
///
/// In an app, call `controller.animateTo(LatLng(lat, lng))` from your
/// location stream instead, for example advanced_background_locator's
/// callback or geolocator's position stream.
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.hasMapsKey});

  final bool hasMapsKey;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with TickerProviderStateMixin {
  static const Duration _interval = Duration(seconds: 1);
  static const double _trueSpeed = 13;

  final RoutePath _road = RoutePath(taxiRoute);
  final math.Random _random = math.Random(7);

  late final AnimatedRouteMarkerController _vehicle = AnimatedRouteMarkerController(
    vsync: this,
    marker: const Marker(markerId: MarkerId('live'), flat: true, anchor: Offset(0.5, 0.5)),
    // Each fix should take as long as the gap to the next one.
    liveDuration: _interval,
    minMoveDistance: 2,
    jumpDistance: 500,
    polylineStyle: const RoutePolylineStyle(
      remainingColor: taxiColor,
      passedColor: Color(0xFFA0AEC0),
      width: 5,
    ),
  );

  Timer? _feed;
  double _travelled = 0;
  bool _jumpNext = false;
  int _accepted = 0;
  int _ignored = 0;
  bool? _lastAccepted;
  GoogleMapController? _mapController;
  bool _follow = false;

  @override
  void initState() {
    super.initState();
    _vehicle.animateTo(_road.points.first);
    vehicleIcon(taxiColor).then((BitmapDescriptor icon) {
      if (mounted) {
        _vehicle.markerTemplate = _vehicle.markerTemplate.copyWith(iconParam: icon);
      }
    });
  }

  @override
  void dispose() {
    _feed?.cancel();
    _vehicle.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _toggleFeed() {
    setState(() {
      if (_feed == null) {
        _feed = Timer.periodic(_interval, (_) => _sendFix());
      } else {
        _feed!.cancel();
        _feed = null;
      }
    });
  }

  /// One simulated fix: the true position on the road plus up to 4 m of
  /// noise, or a 3 km jump when requested.
  void _sendFix() {
    _travelled = (_travelled + _trueSpeed * _interval.inSeconds) % _road.length;
    LatLng fix = _road.positionAt(_travelled).position;
    final double noise = _random.nextDouble() * 4;
    double direction = _random.nextDouble() * 360;
    double meters = noise;
    if (_jumpNext) {
      _jumpNext = false;
      direction = 200;
      meters = 3000;
    }
    fix = _offset(fix, meters, direction);
    final bool accepted = _vehicle.animateTo(fix);
    setState(() {
      _lastAccepted = accepted;
      accepted ? _accepted++ : _ignored++;
    });
  }

  static LatLng _offset(LatLng origin, double meters, double bearing) {
    final double rad = bearing * math.pi / 180;
    final double dLat = meters * math.cos(rad) / 111195;
    final double dLng = meters * math.sin(rad) / (111195 * math.cos(origin.latitude * math.pi / 180));
    return LatLng(origin.latitude + dLat, origin.longitude + dLng);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _applyFollow();
  }

  void _applyFollow() {
    final GoogleMapController? map = _mapController;
    if (_follow && map != null) {
      _vehicle.followCamera(map, zoom: 16.5, tilt: 45, rotate: true);
    } else {
      _vehicle.stopFollowingCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool running = _feed != null;
    return Scaffold(
      appBar: AppBar(title: Text(strings.liveTitle), actions: const <Widget>[LanguageMenu()]),
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
                    controllers: <AnimatedRouteMarkerController>[_vehicle],
                    bounds: taxiRoute,
                    colors: <MarkerId, Color>{const MarkerId('live'): taxiColor},
                    // The road the simulated vehicle drives on, as a guide.
                    staticPolylines: <Polyline>{
                      Polyline(
                        polylineId: const PolylineId('road'),
                        points: taxiRoute,
                        color: scheme.outline.withValues(alpha: 0.35),
                        width: 8,
                        zIndex: -1,
                      ),
                    },
                    onMapCreated: _onMapCreated,
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.sm, Gap.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(strings.liveSubtitle, style: text.bodySmall),
                      const SizedBox(height: Gap.sm),
                      Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _toggleFeed,
                            icon: Icon(running ? Icons.gps_off : Icons.gps_fixed),
                            label: Text(running ? strings.stopFeed : strings.startFeed),
                          ),
                          OutlinedButton.icon(
                            onPressed: running ? () => setState(() => _jumpNext = true) : null,
                            icon: const Icon(Icons.bolt),
                            label: Text(strings.sendJump),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                      Wrap(
                        spacing: Gap.sm,
                        children: <Widget>[
                          Chip(
                            avatar: Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
                            label: Text(strings.accepted(_accepted)),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            avatar: Icon(Icons.block, size: 18, color: scheme.error),
                            label: Text(strings.ignored(_ignored)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (_lastAccepted != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Text(
                            _lastAccepted! ? strings.lastFixAccepted : strings.lastFixIgnored,
                            style: text.labelMedium?.copyWith(
                              color: _lastAccepted! ? scheme.onSurfaceVariant : scheme.error,
                            ),
                          ),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
