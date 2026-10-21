import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_math.dart';
import 'route_path.dart';

/// Playback state of an [AnimatedRouteMarkerController].
enum RouteAnimationStatus {
  /// Not started yet, or reset with [AnimatedRouteMarkerController.stop].
  idle,

  /// Moving.
  playing,

  /// Paused with [AnimatedRouteMarkerController.pause].
  paused,

  /// Reached the end of the route (or, in live mode, the latest position).
  completed,
}

/// Where the marker gets its positions from.
enum RouteAnimationMode {
  /// Follows a whole route given to [AnimatedRouteMarkerController.setRoute].
  route,

  /// Follows positions as they arrive through
  /// [AnimatedRouteMarkerController.animateTo].
  live,
}

/// A snapshot of an animated marker, published on every frame.
@immutable
class RouteProgress {
  const RouteProgress({
    required this.position,
    required this.bearing,
    required this.distance,
    required this.totalDistance,
    required this.segmentIndex,
    required this.status,
    required this.mode,
  });

  /// Current marker position.
  final LatLng position;

  /// Displayed heading in degrees clockwise from north (smoothed, without
  /// the controller's `rotationOffset`).
  final double bearing;

  /// Meters travelled on the current route (in live mode: on the current leg).
  final double distance;

  /// Length of the current route (in live mode: of the current leg) in meters.
  final double totalDistance;

  /// Index of the route point the current segment starts at.
  final int segmentIndex;

  final RouteAnimationStatus status;

  final RouteAnimationMode mode;

  /// Progress from 0 to 1.
  double get fraction {
    if (totalDistance <= 0) {
      return status == RouteAnimationStatus.completed ? 1 : 0;
    }
    return (distance / totalDistance).clamp(0, 1).toDouble();
  }

  /// Meters left to the end of the route.
  double get remainingDistance => math.max(0, totalDistance - distance);

  @override
  String toString() =>
      'RouteProgress(${position.latitude}, ${position.longitude}, bearing: ${bearing.toStringAsFixed(1)}, '
      '${(fraction * 100).toStringAsFixed(1)}%, $status)';
}

/// How the route is drawn under the marker.
@immutable
class RoutePolylineStyle {
  const RoutePolylineStyle({
    this.remainingColor = const Color(0xFF1F6FEB),
    this.passedColor = const Color(0xFF9AA4B2),
    this.width = 6,
    this.passedWidth,
    this.zIndex = 0,
  });

  /// Color of the part still ahead of the marker.
  final Color remainingColor;

  /// Color of the part already travelled. Null hides it.
  final Color? passedColor;

  /// Line width in logical pixels.
  final int width;

  /// Width of the travelled part; defaults to [width].
  final int? passedWidth;

  final int zIndex;
}

class _CameraFollow {
  _CameraFollow(this.move, this.zoom, this.tilt, this.rotate);

  final Future<void> Function(CameraUpdate update) move;
  double? zoom;
  final double? tilt;
  final bool rotate;
}

/// Moves one [Marker] smoothly along a route or towards live positions and
/// turns it towards the direction of travel.
///
/// Create it in a [State] with a [TickerProviderStateMixin] and pass the
/// state as [vsync], like an [AnimationController]; call [dispose] in the
/// state's `dispose`. Read [marker] and [polylines] when building the
/// `GoogleMap` (for several markers, see `AnimatedRouteMarkers`).
///
/// The controller is a [ValueListenable] of [RouteProgress] and also offers
/// the same values as [progressStream].
class AnimatedRouteMarkerController extends ChangeNotifier implements ValueListenable<RouteProgress> {
  AnimatedRouteMarkerController({
    required TickerProvider vsync,
    required Marker marker,
    double speed = 10,
    this.rotationOffset = 0,
    this.rotationDuration = const Duration(milliseconds: 300),
    RoutePolylineStyle? polylineStyle,
    this.onCompleted,
    this.loop = false,
    this.liveDuration = const Duration(seconds: 1),
    this.minMoveDistance = 1,
    this.jumpDistance = 1000,
    this.jumpConfirmations = 2,
    this.maxTrailPoints = 1000,
  })  : assert(speed > 0),
        assert(minMoveDistance >= 0),
        assert(jumpDistance == null || jumpDistance > 0),
        assert(jumpConfirmations >= 1),
        _template = marker,
        _polylineStyle = polylineStyle,
        _speed = speed,
        _position = marker.position,
        _rotation = GeoMath.normalizeAngle(marker.rotation - rotationOffset) {
    _ticker = vsync.createTicker(_tick);
    _targetBearing = _rotation;
    _value = _snapshot();
  }

  /// Degrees added to the heading when the marker is drawn. Use it when the
  /// icon does not point north: an icon pointing east needs `-90`.
  final double rotationOffset;

  /// About how long a turn takes. The heading follows the route with an
  /// exponential easing, always turning the short way (359° → 1° is a 2°
  /// turn). [Duration.zero] turns instantly.
  Duration rotationDuration;

  /// Draws the route under the marker when not null; see [polylines].
  RoutePolylineStyle? get polylineStyle => _polylineStyle;
  RoutePolylineStyle? _polylineStyle;

  set polylineStyle(RoutePolylineStyle? value) {
    _polylineStyle = value;
    _polylineCache = null;
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Called when the marker reaches the end of a route (route mode only,
  /// not while [loop]ing).
  VoidCallback? onCompleted;

  /// Starts the route over when it ends, until [pause] or [stop].
  bool loop;

  /// Default time to move to a new position in live mode. Set it to the
  /// interval of your location updates so the marker arrives just as the
  /// next one comes in.
  Duration liveDuration;

  /// Live positions closer than this many meters to the previous one are
  /// ignored, so GPS noise does not make a parked marker jitter or spin.
  double minMoveDistance;

  /// A live position farther than this many meters from the previous one is
  /// treated as a GPS jump: it is ignored until [jumpConfirmations]
  /// consecutive positions agree on it, then the marker jumps there without
  /// sliding across the map. Null disables the check.
  double? jumpDistance;

  /// How many consecutive far positions confirm a real jump; see
  /// [jumpDistance].
  int jumpConfirmations;

  /// Maximum number of points kept for the travelled line in live mode.
  int maxTrailPoints;

  late final Ticker _ticker;
  final StreamController<RouteProgress> _streamController = StreamController<RouteProgress>.broadcast();

  Marker _template;
  RoutePath? _path;
  double _distance = 0;
  double _speed;
  LatLng _position;
  double _rotation;
  late double _targetBearing;
  RouteAnimationStatus _status = RouteAnimationStatus.idle;
  RouteAnimationMode _mode = RouteAnimationMode.route;
  Duration _lastElapsed = Duration.zero;
  late RouteProgress _value;

  final List<LatLng> _trail = <LatLng>[];
  LatLng? _pendingJump;
  int _pendingJumpCount = 0;

  _CameraFollow? _follow;
  bool _cameraBusy = false;
  bool _cameraDirty = false;

  Set<Polyline>? _polylineCache;
  bool _disposed = false;

  @override
  RouteProgress get value => _value;

  /// The same snapshots as [value], one per frame while moving.
  Stream<RouteProgress> get progressStream => _streamController.stream;

  RouteAnimationStatus get status => _status;

  RouteAnimationMode get mode => _mode;

  /// The current route; null before [setRoute], [animateTo] or [jumpTo].
  RoutePath? get path => _path;

  /// Speed along the route in meters per second.
  double get speed => _speed;

  set speed(double value) {
    assert(value > 0);
    _speed = value;
  }

  /// The marker at its current position and heading.
  Marker get marker => _template.copyWith(
        positionParam: _position,
        rotationParam: GeoMath.normalizeAngle(_rotation + rotationOffset),
      );

  /// The template the [marker] is built from. Position and rotation are
  /// replaced on every frame; everything else (icon, anchor, `flat`,
  /// callbacks, …) is kept. Set it to change the icon at any time.
  set markerTemplate(Marker value) {
    _template = value;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Marker get markerTemplate => _template;

  /// The travelled and remaining parts of the route, styled with
  /// [polylineStyle]. Empty when [polylineStyle] is null.
  Set<Polyline> get polylines => _polylineCache ??= _buildPolylines();

  /// Starts a route. Give either [speed] in meters per second or the total
  /// [duration] of the trip; with neither, the current [speed] is kept.
  /// The marker is placed at the first point, facing the first segment.
  ///
  /// Throws an [ArgumentError] if [points] is empty.
  void setRoute(List<LatLng> points, {double? speed, Duration? duration, bool autoPlay = false}) {
    assert(speed == null || duration == null, 'Give either speed or duration, not both.');
    assert(speed == null || speed > 0);
    assert(duration == null || duration > Duration.zero);
    final RoutePath path = RoutePath(points);
    _ticker.stop();
    _mode = RouteAnimationMode.route;
    _path = path;
    _distance = 0;
    _trail.clear();
    _clearPendingJump();
    if (speed != null) {
      _speed = speed;
    } else if (duration != null && path.length > 0) {
      _speed = path.length / (duration.inMicroseconds / Duration.microsecondsPerSecond);
    }
    _snapTo(path.positionAt(0));
    _status = RouteAnimationStatus.idle;
    _emit();
    if (autoPlay) {
      play();
    }
  }

  /// Starts or resumes moving. A completed route starts over.
  ///
  /// Throws a [StateError] before a route or position was given.
  void play() {
    final RoutePath? path = _path;
    if (path == null) {
      throw StateError('Call setRoute or animateTo before play.');
    }
    if (_status == RouteAnimationStatus.playing) {
      return;
    }
    if (_mode == RouteAnimationMode.route && _status == RouteAnimationStatus.completed) {
      _distance = 0;
      _snapTo(path.positionAt(0));
    }
    _status = RouteAnimationStatus.playing;
    _emit();
    _startTicker();
  }

  /// Pauses where the marker is; [play] resumes.
  void pause() {
    if (_status != RouteAnimationStatus.playing) {
      return;
    }
    _ticker.stop();
    _status = RouteAnimationStatus.paused;
    _emit();
  }

  /// Stops moving. A route goes back to its start; in live mode the marker
  /// stays where it is and drops the position it was heading to.
  void stop() {
    _ticker.stop();
    final RoutePath? path = _path;
    if (path != null) {
      if (_mode == RouteAnimationMode.route) {
        _distance = 0;
        _snapTo(path.positionAt(0));
      } else {
        _path = RoutePath(<LatLng>[_position]);
        _distance = 0;
      }
    }
    _status = RouteAnimationStatus.idle;
    _emit();
  }

  /// Jumps to [fraction] (0–1) of the route. Keeps playing if it was.
  void seek(double fraction) {
    final RoutePath? path = _path;
    if (path == null) {
      throw StateError('Call setRoute before seek.');
    }
    seekToDistance(fraction.clamp(0, 1) * path.length);
  }

  /// Jumps to [meters] from the start of the route. Keeps playing if it was.
  void seekToDistance(double meters) {
    final RoutePath? path = _path;
    if (path == null) {
      throw StateError('Call setRoute before seekToDistance.');
    }
    _distance = meters.clamp(0, path.length).toDouble();
    _snapTo(path.positionAt(_distance));
    if (_status == RouteAnimationStatus.completed && _distance < path.length) {
      _status = RouteAnimationStatus.paused;
    } else if (_status != RouteAnimationStatus.playing && path.length > 0 && _distance >= path.length) {
      _status = RouteAnimationStatus.completed;
    }
    _emit();
  }

  /// Live mode: moves from where the marker is now to [position] in
  /// [duration] (default [liveDuration]), for example on every update from a
  /// location stream. A new position that arrives mid-way continues from the
  /// current point, so there is no jump.
  ///
  /// Returns false when the position was ignored: it was closer than
  /// [minMoveDistance], or it is an unconfirmed jump (see [jumpDistance]).
  /// The first position (and every confirmed jump) places the marker
  /// directly. While [pause]d, the marker waits and moves on [play].
  bool animateTo(LatLng position, {Duration? duration, double? bearing}) {
    final RoutePath? path = _path;
    if (path == null) {
      jumpTo(position, bearing: bearing);
      return true;
    }
    final LatLng previous = _mode == RouteAnimationMode.live ? path.points.last : _position;
    final double moved = GeoMath.distance(previous, position);
    final double? jump = jumpDistance;
    if (jump != null && moved > jump) {
      final LatLng? pending = _pendingJump;
      if (pending != null && GeoMath.distance(pending, position) <= jump) {
        _pendingJumpCount++;
      } else {
        _pendingJumpCount = 1;
      }
      _pendingJump = position;
      if (_pendingJumpCount >= jumpConfirmations) {
        jumpTo(position, bearing: bearing);
        return true;
      }
      return false;
    }
    _clearPendingJump();
    if (moved < minMoveDistance) {
      return false;
    }

    final Duration legDuration = duration ?? liveDuration;
    if (_mode != RouteAnimationMode.live) {
      _mode = RouteAnimationMode.live;
      _trail.clear();
    }
    _addTrailPoint(_position);
    final RoutePath leg = RoutePath(<LatLng>[_position, position]);
    _path = leg;
    _distance = 0;
    if (leg.length > 0) {
      _speed = legDuration > Duration.zero
          ? leg.length / (legDuration.inMicroseconds / Duration.microsecondsPerSecond)
          : double.infinity;
    }
    if (bearing != null) {
      _targetBearing = GeoMath.normalizeAngle(bearing);
    }
    if (_status != RouteAnimationStatus.paused) {
      _status = RouteAnimationStatus.playing;
      _startTicker();
    }
    _emit();
    return true;
  }

  /// Live mode: places the marker at [position] at once, without animation,
  /// and starts a new travelled line there. [bearing] sets the heading;
  /// without it the heading is kept.
  void jumpTo(LatLng position, {double? bearing}) {
    _ticker.stop();
    _mode = RouteAnimationMode.live;
    _path = RoutePath(<LatLng>[position]);
    _distance = 0;
    _position = position;
    _trail.clear();
    _clearPendingJump();
    if (bearing != null) {
      _rotation = _targetBearing = GeoMath.normalizeAngle(bearing);
    }
    _status = RouteAnimationStatus.completed;
    _emit();
  }

  /// Keeps the camera of [controller] centered on the marker. With [zoom],
  /// [tilt] or [rotate] (turn the map with the marker heading), a full camera
  /// position is sent; without them only the target changes and the user
  /// keeps their zoom.
  void followCamera(GoogleMapController controller, {double? zoom, double? tilt, bool rotate = false}) {
    followCameraWith(controller.moveCamera, zoom: zoom, tilt: tilt, rotate: rotate);
    if (zoom == null && (rotate || tilt != null)) {
      final _CameraFollow follow = _follow!;
      controller.getZoomLevel().then((double level) {
        follow.zoom ??= level;
      }).catchError((Object _) {});
    }
  }

  /// Like [followCamera], with the function that moves the camera. Useful
  /// for tests or other map widgets.
  void followCameraWith(
    Future<void> Function(CameraUpdate update) moveCamera, {
    double? zoom,
    double? tilt,
    bool rotate = false,
  }) {
    _follow = _CameraFollow(moveCamera, zoom, tilt, rotate);
    _moveCamera();
  }

  /// Stops [followCamera].
  void stopFollowingCamera() {
    _follow = null;
  }

  bool get isFollowingCamera => _follow != null;

  void _moveCamera() {
    final _CameraFollow? follow = _follow;
    if (follow == null || _disposed) {
      return;
    }
    // One camera move at a time: frames that arrive while the map is still
    // busy are merged into one move afterwards.
    if (_cameraBusy) {
      _cameraDirty = true;
      return;
    }
    final double? zoom = follow.zoom;
    final CameraUpdate update = zoom == null
        ? CameraUpdate.newLatLng(_position)
        : CameraUpdate.newCameraPosition(CameraPosition(
            target: _position,
            zoom: zoom,
            tilt: follow.tilt ?? 0,
            bearing: follow.rotate ? _rotation : 0,
          ));
    _cameraBusy = true;
    _cameraDirty = false;
    Future<void>.sync(() => follow.move(update)).catchError((Object _) {}).whenComplete(() {
      _cameraBusy = false;
      if (_cameraDirty) {
        _moveCamera();
      }
    });
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final double dt = (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    final RoutePath? path = _path;
    if (path == null) {
      _ticker.stop();
      return;
    }
    if (_status == RouteAnimationStatus.playing && _distance < path.length) {
      _distance = math.min(path.length, _distance + _speed * dt);
    }
    final RoutePosition at = path.positionAt(_distance);
    _position = at.position;
    if (path.length > 0 && _distance < path.length) {
      _targetBearing = at.bearing;
    }
    _rotation = _smoothRotation(_rotation, _targetBearing, dt);

    VoidCallback? completed;
    if (_status == RouteAnimationStatus.playing && _distance >= path.length) {
      if (_mode == RouteAnimationMode.route && loop && path.length > 0) {
        _distance = 0;
        _snapTo(path.positionAt(0));
      } else if (_mode == RouteAnimationMode.route) {
        _ticker.stop();
        _status = RouteAnimationStatus.completed;
        completed = onCompleted;
      } else if (GeoMath.shortestAngleDelta(_rotation, _targetBearing).abs() < 0.5) {
        // Live mode waits for the turn to finish before stopping.
        _rotation = _targetBearing;
        _ticker.stop();
        _status = RouteAnimationStatus.completed;
      }
    }
    _emit();
    completed?.call();
  }

  double _smoothRotation(double current, double target, double dt) {
    final double seconds = rotationDuration.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) {
      return target;
    }
    // Frame-rate independent easing, about 95 % of the turn in
    // [rotationDuration].
    final double t = 1 - math.exp(-3 * dt / seconds);
    return GeoMath.lerpAngle(current, target, t);
  }

  void _snapTo(RoutePosition at) {
    _position = at.position;
    if (_path!.length > 0) {
      _rotation = _targetBearing = at.bearing;
    }
  }

  void _addTrailPoint(LatLng point) {
    if (_trail.isEmpty || _trail.last != point) {
      _trail.add(point);
    }
    if (_trail.length > maxTrailPoints) {
      _trail.removeRange(0, _trail.length - maxTrailPoints);
    }
  }

  void _clearPendingJump() {
    _pendingJump = null;
    _pendingJumpCount = 0;
  }

  Set<Polyline> _buildPolylines() {
    final RoutePolylineStyle? style = _polylineStyle;
    final RoutePath? path = _path;
    if (style == null || path == null) {
      return const <Polyline>{};
    }
    final List<LatLng> passed;
    final List<LatLng> remaining;
    if (_mode == RouteAnimationMode.route) {
      passed = path.passedPoints(_distance);
      remaining = path.remainingPoints(_distance);
    } else {
      passed = <LatLng>[..._trail, _position];
      remaining = _distance < path.length ? <LatLng>[_position, path.points.last] : const <LatLng>[];
    }
    final String id = _template.markerId.value;
    final Color? passedColor = style.passedColor;
    return <Polyline>{
      if (remaining.length > 1)
        Polyline(
          polylineId: PolylineId('$id#remaining'),
          points: remaining,
          color: style.remainingColor,
          width: style.width,
          zIndex: style.zIndex,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      if (passedColor != null && passed.length > 1)
        Polyline(
          polylineId: PolylineId('$id#passed'),
          points: passed,
          color: passedColor,
          width: style.passedWidth ?? style.width,
          zIndex: style.zIndex,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };
  }

  RouteProgress _snapshot() {
    final RoutePath? path = _path;
    return RouteProgress(
      position: _position,
      bearing: _rotation,
      distance: _distance,
      totalDistance: path?.length ?? 0,
      segmentIndex: path == null ? 0 : path.segmentAt(_distance),
      status: _status,
      mode: _mode,
    );
  }

  void _emit() {
    if (_disposed) {
      return;
    }
    _polylineCache = null;
    _value = _snapshot();
    notifyListeners();
    if (_streamController.hasListener) {
      _streamController.add(_value);
    }
    _moveCamera();
  }

  /// Stops the ticker, closes [progressStream] and releases listeners.
  @override
  void dispose() {
    _disposed = true;
    _follow = null;
    _ticker.dispose();
    _streamController.close();
    super.dispose();
  }
}
