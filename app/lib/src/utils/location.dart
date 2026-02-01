import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "geo.dart";

Future<LatLng> getCurrentLocationOrDefault() async {
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
