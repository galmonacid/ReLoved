import "dart:math" as math;

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

int geohashPrecisionForRadiusKm(double radiusKm) {
  if (radiusKm <= 1.2) {
    return 6;
  }
  if (radiusKm <= 4.9) {
    return 5;
  }
  if (radiusKm <= 39.1) {
    return 4;
  }
  if (radiusKm <= 156) {
    return 3;
  }
  return 2;
}

LatLng offsetByDistance(
  LatLng origin, {
  required double distanceKm,
  required double bearingDegrees,
}) {
  const earthRadiusKm = 6371.0;
  final angularDistance = distanceKm / earthRadiusKm;
  final bearing = bearingDegrees * math.pi / 180.0;
  final lat1 = origin.latitudeInRad;
  final lng1 = origin.longitudeInRad;

  final lat2 = math.asin(
    (math.sin(lat1) * math.cos(angularDistance)) +
        (math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing)),
  );
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
        math.cos(angularDistance) - (math.sin(lat1) * math.sin(lat2)),
      );

  return LatLng(lat2 * 180.0 / math.pi, lng2 * 180.0 / math.pi);
}

List<String> geohashPrefixesForRadius(LatLng center, double radiusKm) {
  final effectiveRadiusKm = radiusKm <= 0 ? 1.0 : radiusKm;
  final precision = geohashPrecisionForRadiusKm(effectiveRadiusKm);
  final samplePoints = <LatLng>[
    center,
    offsetByDistance(center, distanceKm: effectiveRadiusKm, bearingDegrees: 0),
    offsetByDistance(center, distanceKm: effectiveRadiusKm, bearingDegrees: 45),
    offsetByDistance(center, distanceKm: effectiveRadiusKm, bearingDegrees: 90),
    offsetByDistance(
      center,
      distanceKm: effectiveRadiusKm,
      bearingDegrees: 135,
    ),
    offsetByDistance(
      center,
      distanceKm: effectiveRadiusKm,
      bearingDegrees: 180,
    ),
    offsetByDistance(
      center,
      distanceKm: effectiveRadiusKm,
      bearingDegrees: 225,
    ),
    offsetByDistance(
      center,
      distanceKm: effectiveRadiusKm,
      bearingDegrees: 270,
    ),
    offsetByDistance(
      center,
      distanceKm: effectiveRadiusKm,
      bearingDegrees: 315,
    ),
  ];

  final prefixes =
      samplePoints
          .map(
            (point) => encodeGeohash(
              point.latitude,
              point.longitude,
              precision: precision,
            ),
          )
          .map((hash) => hash.substring(0, precision))
          .toSet()
          .toList()
        ..sort();

  return prefixes;
}
