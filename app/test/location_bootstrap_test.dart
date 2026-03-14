import "package:app/src/utils/location.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("bootstrapCurrentLocation", () {
    test(
      "returns resolved when services and permission are available",
      () async {
        final result = await bootstrapCurrentLocation(
          client: _FakeLocationAccessClient(
            serviceEnabled: true,
            permission: LocationPermission.whileInUse,
            currentLocation: const LatLng(51.501, -0.141),
          ),
        );

        expect(result.status, LocationBootstrapStatus.resolved);
        expect(result.location, const LatLng(51.501, -0.141));
        expect(result.reason, isNull);
      },
    );

    test("returns unavailable when permission is denied", () async {
      final result = await bootstrapCurrentLocation(
        client: _FakeLocationAccessClient(
          serviceEnabled: true,
          permission: LocationPermission.denied,
          requestedPermission: LocationPermission.denied,
        ),
      );

      expect(result.status, LocationBootstrapStatus.unavailable);
      expect(result.reason, LocationBootstrapFailureReason.permissionDenied);
    });

    test("returns unavailable when permission is denied forever", () async {
      final result = await bootstrapCurrentLocation(
        client: _FakeLocationAccessClient(
          serviceEnabled: true,
          permission: LocationPermission.deniedForever,
        ),
      );

      expect(result.status, LocationBootstrapStatus.unavailable);
      expect(
        result.reason,
        LocationBootstrapFailureReason.permissionDeniedForever,
      );
    });

    test("returns unavailable when location services are disabled", () async {
      final result = await bootstrapCurrentLocation(
        client: _FakeLocationAccessClient(
          serviceEnabled: false,
          permission: LocationPermission.whileInUse,
        ),
      );

      expect(result.status, LocationBootstrapStatus.unavailable);
      expect(result.reason, LocationBootstrapFailureReason.serviceDisabled);
    });

    test("returns unavailable when the location lookup throws", () async {
      final result = await bootstrapCurrentLocation(
        client: _FakeLocationAccessClient(
          serviceEnabled: true,
          permission: LocationPermission.whileInUse,
          throwOnCurrentLocation: true,
        ),
      );

      expect(result.status, LocationBootstrapStatus.unavailable);
      expect(result.reason, LocationBootstrapFailureReason.lookupFailed);
    });
  });
}

class _FakeLocationAccessClient implements LocationAccessClient {
  _FakeLocationAccessClient({
    required this.serviceEnabled,
    required this.permission,
    this.requestedPermission,
    this.currentLocation,
    this.throwOnCurrentLocation = false,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission? requestedPermission;
  final LatLng? currentLocation;
  final bool throwOnCurrentLocation;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LatLng> getCurrentLocation({
    LocationAccuracy desiredAccuracy = LocationAccuracy.low,
  }) async {
    if (throwOnCurrentLocation) {
      throw Exception("lookup failed");
    }
    return currentLocation ?? const LatLng(0, 0);
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<LocationPermission> requestPermission() async {
    return requestedPermission ?? permission;
  }
}
