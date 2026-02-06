import "dart:convert";
import "package:http/http.dart" as http;
import "package:latlong2/latlong.dart";

class PostcodeResult {
  const PostcodeResult({
    required this.postcode,
    required this.location,
  });

  final String postcode;
  final LatLng location;
}

Future<PostcodeResult?> lookupUkPostcode(String rawPostcode) async {
  final cleaned = rawPostcode.trim();
  if (cleaned.isEmpty) return null;
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
  return PostcodeResult(
    postcode: postcode,
    location: LatLng(lat.toDouble(), lng.toDouble()),
  );
}

Future<String?> reverseUkPostcode(LatLng location) async {
  final uri = Uri.https(
    "api.postcodes.io",
    "/postcodes",
    {
      "lon": location.longitude.toString(),
      "lat": location.latitude.toString(),
    },
  );
  final response = await http.get(uri);
  if (response.statusCode != 200) return null;
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final results = data["result"];
  if (results is! List || results.isEmpty) return null;
  final first = results.first as Map<String, dynamic>?;
  final postcode = first?["postcode"];
  if (postcode is! String) return null;
  return postcode;
}
