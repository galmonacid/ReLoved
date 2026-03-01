import "package:latlong2/latlong.dart";

const LatLng defaultCenter = LatLng(52.0406, -0.7594);
const String _geohashBase32 = "0123456789bcdefghjkmnpqrstuvwxyz";

double distanceKm(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Kilometer, a, b);
}

String encodeGeohash(double lat, double lng, {int precision = 9}) {
  var isEven = true;
  var bit = 0;
  var ch = 0;
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  final geohash = StringBuffer();

  while (geohash.length < precision) {
    if (isEven) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }

    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      geohash.write(_geohashBase32[ch]);
      bit = 0;
      ch = 0;
    }
  }

  return geohash.toString();
}
