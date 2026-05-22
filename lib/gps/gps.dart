import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Thin domain-friendly wrapper around the Geolocator plugin.
///
/// Centralises the permission-prompt logic so neither the Sales App's
/// lead-create wizard nor the Tech App's checklist screens have to
/// re-implement it. Both call [currentPosition] and either get a
/// [GpsFix] or a [GpsError] describing what's missing.
class GpsService {
  GpsService({GeolocatorPlatform? platform})
      : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  /// Resolves the device's current position with a hardware GPS fix.
  ///
  /// Throws [GpsError] on every failure mode the caller cares about
  /// (services off, permission denied, timeout) so the UI can branch
  /// without parsing platform exceptions.
  Future<GpsFix> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!await _platform.isLocationServiceEnabled()) {
      throw const GpsError.servicesOff();
    }
    var perm = await _platform.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await _platform.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw const GpsError.permissionDenied();
    }
    try {
      final pos = await _platform.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeout),
      );
      return GpsFix(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        timestamp: pos.timestamp ?? DateTime.now().toUtc(),
      );
    } on TimeoutException catch (_) {
      throw const GpsError.timeout();
    } on Exception catch (e) {
      throw GpsError.platform(e.toString());
    }
  }
}

/// A single fix from the device. We use SI units (metres for accuracy)
/// to match the backend's checklist GPS gate expectations.
class GpsFix {
  const GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.timestamp,
  });
  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime timestamp;
}

/// Strongly-typed failure model. The UI can switch on [kind] to render
/// a tailored prompt (open Settings, retry, etc.).
class GpsError implements Exception {
  const GpsError(this.kind, [this.detail]);
  const GpsError.servicesOff() : this(GpsErrorKind.servicesOff);
  const GpsError.permissionDenied() : this(GpsErrorKind.permissionDenied);
  const GpsError.timeout() : this(GpsErrorKind.timeout);
  const GpsError.platform(String detail) : this(GpsErrorKind.platform, detail);

  final GpsErrorKind kind;
  final String? detail;

  @override
  String toString() => 'GpsError(${kind.name})${detail != null ? ': $detail' : ''}';
}

enum GpsErrorKind { servicesOff, permissionDenied, timeout, platform }
