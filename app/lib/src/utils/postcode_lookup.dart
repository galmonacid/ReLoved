import "dart:convert";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";

import "../config/e2e_config.dart";

class PostcodeResult {
  const PostcodeResult({required this.postcode, required this.location});

  final String postcode;
  final LatLng location;
}

final Map<String, PostcodeResult> _postcodeCache = {};
final Map<String, String> _reverseCache = {};

String normalizeUkPostcode(String raw) {
  var decoded = raw;
  for (var i = 0; i < 2; i += 1) {
    if (!decoded.contains("%")) break;
    try {
      decoded = Uri.decodeComponent(decoded);
    } catch (_) {
      break;
    }
  }
  final trimmed = decoded.trim().toUpperCase().replaceAll(RegExp(r"\s+"), "");
  return trimmed;
}

Future<PostcodeResult?> lookupUkPostcode(String rawPostcode) async {
  if (E2EConfig.enabled) {
    return PostcodeResult(
      postcode: E2EConfig.fixedPostcode,
      location: const LatLng(52.0406, -0.7594),
    );
  }
  final cleaned = normalizeUkPostcode(rawPostcode);
  if (cleaned.isEmpty) return null;
  final cached = _postcodeCache[cleaned];
  if (cached != null) return cached;
  final uri = Uri.https(
    "api.postcodes.io",
    "/postcodes/${Uri.encodeComponent(cleaned)}",
  );
  final response = await http.get(uri);
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final result = data["result"] as Map<String, dynamic>?;
  if (result == null) return null;
  final lat = result["latitude"];
  final lng = result["longitude"];
  final postcode = result["postcode"];
  if (lat is! num || lng is! num || postcode is! String) {
    return null;
  }
  final resultValue = PostcodeResult(
    postcode: postcode,
    location: LatLng(lat.toDouble(), lng.toDouble()),
  );
  _postcodeCache[cleaned] = resultValue;
  return resultValue;
}

Future<String?> reverseUkPostcode(LatLng location) async {
  if (E2EConfig.enabled) {
    return E2EConfig.fixedPostcode;
  }
  final key =
      "${location.latitude.toStringAsFixed(4)},${location.longitude.toStringAsFixed(4)}";
  final cached = _reverseCache[key];
  if (cached != null) return cached;
  final uri = Uri.https("api.postcodes.io", "/postcodes", {
    "lon": location.longitude.toString(),
    "lat": location.latitude.toString(),
  });
  final response = await http.get(uri);
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final results = data["result"];
  if (results is! List || results.isEmpty) return null;
  final first = results.first as Map<String, dynamic>?;
  final postcode = first?["postcode"];
  if (postcode is! String) return null;
  _reverseCache[key] = postcode;
  return postcode;
}
