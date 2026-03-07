import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "../config/e2e_config.dart";
import "geo.dart";

Future<LatLng> getCurrentLocationOrDefault() async {
  if (E2EConfig.enabled) {
    return defaultCenter;
  }
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return defaultCenter;
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return defaultCenter;
  }

  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.low,
  );
  return LatLng(position.latitude, position.longitude);
}
