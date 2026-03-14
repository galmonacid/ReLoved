import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "../config/e2e_config.dart";

enum LocationBootstrapStatus { loading, resolved, unavailable }

enum LocationBootstrapFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  lookupFailed,
}

class LocationBootstrapResult {
  const LocationBootstrapResult._({
    required this.status,
    this.location,
    this.reason,
  });

  const LocationBootstrapResult.loading()
    : this._(status: LocationBootstrapStatus.loading);

  const LocationBootstrapResult.resolved(LatLng location)
    : this._(status: LocationBootstrapStatus.resolved, location: location);

  const LocationBootstrapResult.unavailable(
    LocationBootstrapFailureReason reason,
  ) : this._(status: LocationBootstrapStatus.unavailable, reason: reason);

  final LocationBootstrapStatus status;
  final LatLng? location;
  final LocationBootstrapFailureReason? reason;

  bool get isResolved =>
      status == LocationBootstrapStatus.resolved && location != null;

  bool get isUnavailable => status == LocationBootstrapStatus.unavailable;

  String get analyticsStatus {
    switch (status) {
      case LocationBootstrapStatus.loading:
        return "loading";
      case LocationBootstrapStatus.resolved:
        return "resolved";
      case LocationBootstrapStatus.unavailable:
        return "unavailable";
    }
  }

  String? get analyticsReason {
    final failureReason = reason;
    if (failureReason == null) {
      return null;
    }
    return locationBootstrapFailureReasonWire(failureReason);
  }
}

abstract class LocationAccessClient {
  const LocationAccessClient();

  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<LatLng> getCurrentLocation({
    LocationAccuracy desiredAccuracy = LocationAccuracy.low,
  });
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationAccessClient implements LocationAccessClient {
  const GeolocatorLocationAccessClient();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<LatLng> getCurrentLocation({
    LocationAccuracy desiredAccuracy = LocationAccuracy.low,
  }) async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: desiredAccuracy,
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}

Future<LocationBootstrapResult> bootstrapCurrentLocation({
  LocationAccessClient client = const GeolocatorLocationAccessClient(),
}) async {
  if (E2EConfig.enabled) {
    return LocationBootstrapResult.resolved(E2EConfig.fixedLocation);
  }

  final serviceEnabled = await client.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return const LocationBootstrapResult.unavailable(
      LocationBootstrapFailureReason.serviceDisabled,
    );
  }

  var permission = await client.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await client.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    return const LocationBootstrapResult.unavailable(
      LocationBootstrapFailureReason.permissionDenied,
    );
  }
  if (permission == LocationPermission.deniedForever) {
    return const LocationBootstrapResult.unavailable(
      LocationBootstrapFailureReason.permissionDeniedForever,
    );
  }

  try {
    final location = await client.getCurrentLocation(
      desiredAccuracy: LocationAccuracy.low,
    );
    return LocationBootstrapResult.resolved(location);
  } catch (_) {
    return const LocationBootstrapResult.unavailable(
      LocationBootstrapFailureReason.lookupFailed,
    );
  }
}

bool locationBootstrapFailureNeedsSettings(
  LocationBootstrapFailureReason reason,
) {
  return reason == LocationBootstrapFailureReason.serviceDisabled ||
      reason == LocationBootstrapFailureReason.permissionDeniedForever;
}

String locationBootstrapFailureActionLabel(
  LocationBootstrapFailureReason reason,
) {
  return locationBootstrapFailureNeedsSettings(reason)
      ? "Enable location"
      : "Use current location";
}

String locationBootstrapFailureReasonWire(
  LocationBootstrapFailureReason reason,
) {
  switch (reason) {
    case LocationBootstrapFailureReason.serviceDisabled:
      return "service_disabled";
    case LocationBootstrapFailureReason.permissionDenied:
      return "permission_denied";
    case LocationBootstrapFailureReason.permissionDeniedForever:
      return "permission_denied_forever";
    case LocationBootstrapFailureReason.lookupFailed:
      return "lookup_failed";
  }
}

String locationBootstrapFailureMessage(LocationBootstrapFailureReason reason) {
  switch (reason) {
    case LocationBootstrapFailureReason.serviceDisabled:
      return "Location Services are off on this iPhone. Enable them to search nearby items.";
    case LocationBootstrapFailureReason.permissionDenied:
      return "Location access was denied, so the app could not find items near you.";
    case LocationBootstrapFailureReason.permissionDeniedForever:
      return "Location access is disabled for ReLoved. Enable it in Settings to use your current area.";
    case LocationBootstrapFailureReason.lookupFailed:
      return "The app could not determine your current location. Try again or choose an area manually.";
  }
}

Future<bool> openLocationBootstrapSettings({
  required LocationBootstrapFailureReason reason,
  LocationAccessClient client = const GeolocatorLocationAccessClient(),
}) {
  if (reason == LocationBootstrapFailureReason.serviceDisabled) {
    return client.openLocationSettings();
  }
  return client.openAppSettings();
}
