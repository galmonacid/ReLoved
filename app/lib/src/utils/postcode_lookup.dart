import "dart:async";
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

class PostcodeLookupStep {
  const PostcodeLookupStep({
    required this.status,
    this.elapsedMs,
    this.reason,
  });

  final String status;
  final int? elapsedMs;
  final String? reason;
}

typedef PostcodeLookupStepReporter = void Function(PostcodeLookupStep step);

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

Future<PostcodeResult?> lookupUkPostcode(
  String rawPostcode, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 5),
  PostcodeLookupStepReporter? onStep,
}) async {
  if (E2EConfig.enabled) {
    onStep?.call(const PostcodeLookupStep(status: "success", elapsedMs: 0));
    return PostcodeResult(
      postcode: E2EConfig.fixedPostcode,
      location: const LatLng(52.0406, -0.7594),
    );
  }
  final cleaned = normalizeUkPostcode(rawPostcode);
  if (cleaned.isEmpty) {
    onStep?.call(
      const PostcodeLookupStep(status: "empty", reason: "empty_input"),
    );
    return null;
  }
  final cached = _postcodeCache[cleaned];
  if (cached != null) {
    onStep?.call(
      const PostcodeLookupStep(status: "success", elapsedMs: 0, reason: "cache"),
    );
    return cached;
  }
  final uri = Uri.https(
    "api.postcodes.io",
    "/postcodes/${Uri.encodeComponent(cleaned)}",
  );
  onStep?.call(const PostcodeLookupStep(status: "start"));
  final stopwatch = Stopwatch()..start();
  try {
    final response = await _httpGet(uri, client: client, timeout: timeout);
    if (response.statusCode != 200) {
      onStep?.call(
        PostcodeLookupStep(
          status: "error",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "http_${response.statusCode}",
        ),
      );
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = data["result"] as Map<String, dynamic>?;
    if (result == null) {
      onStep?.call(
        PostcodeLookupStep(
          status: "empty",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "no_result",
        ),
      );
      return null;
    }
    final lat = result["latitude"];
    final lng = result["longitude"];
    final postcode = result["postcode"];
    if (lat is! num || lng is! num || postcode is! String) {
      onStep?.call(
        PostcodeLookupStep(
          status: "error",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "invalid_payload",
        ),
      );
      return null;
    }
    final resultValue = PostcodeResult(
      postcode: postcode,
      location: LatLng(lat.toDouble(), lng.toDouble()),
    );
    _postcodeCache[cleaned] = resultValue;
    onStep?.call(
      PostcodeLookupStep(
        status: "success",
        elapsedMs: stopwatch.elapsedMilliseconds,
      ),
    );
    return resultValue;
  } on TimeoutException {
    onStep?.call(
      PostcodeLookupStep(
        status: "timeout",
        elapsedMs: stopwatch.elapsedMilliseconds,
        reason: "timeout",
      ),
    );
    return null;
  } catch (_) {
    onStep?.call(
      PostcodeLookupStep(
        status: "error",
        elapsedMs: stopwatch.elapsedMilliseconds,
        reason: "exception",
      ),
    );
    return null;
  }
}

Future<String?> reverseUkPostcode(
  LatLng location, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 5),
  PostcodeLookupStepReporter? onStep,
}) async {
  if (E2EConfig.enabled) {
    onStep?.call(const PostcodeLookupStep(status: "success", elapsedMs: 0));
    return E2EConfig.fixedPostcode;
  }
  final key =
      "${location.latitude.toStringAsFixed(4)},${location.longitude.toStringAsFixed(4)}";
  final cached = _reverseCache[key];
  if (cached != null) {
    onStep?.call(
      const PostcodeLookupStep(status: "success", elapsedMs: 0, reason: "cache"),
    );
    return cached;
  }
  final uri = Uri.https("api.postcodes.io", "/postcodes", {
    "lon": location.longitude.toString(),
    "lat": location.latitude.toString(),
  });
  onStep?.call(const PostcodeLookupStep(status: "start"));
  final stopwatch = Stopwatch()..start();
  try {
    final response = await _httpGet(uri, client: client, timeout: timeout);
    if (response.statusCode != 200) {
      onStep?.call(
        PostcodeLookupStep(
          status: "error",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "http_${response.statusCode}",
        ),
      );
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data["result"];
    if (results is! List || results.isEmpty) {
      onStep?.call(
        PostcodeLookupStep(
          status: "empty",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "no_result",
        ),
      );
      return null;
    }
    final first = results.first as Map<String, dynamic>?;
    final postcode = first?["postcode"];
    if (postcode is! String) {
      onStep?.call(
        PostcodeLookupStep(
          status: "error",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "invalid_payload",
        ),
      );
      return null;
    }
    _reverseCache[key] = postcode;
    onStep?.call(
      PostcodeLookupStep(
        status: "success",
        elapsedMs: stopwatch.elapsedMilliseconds,
      ),
    );
    return postcode;
  } on TimeoutException {
    onStep?.call(
      PostcodeLookupStep(
        status: "timeout",
        elapsedMs: stopwatch.elapsedMilliseconds,
        reason: "timeout",
      ),
    );
    return null;
  } catch (_) {
    onStep?.call(
      PostcodeLookupStep(
        status: "error",
        elapsedMs: stopwatch.elapsedMilliseconds,
        reason: "exception",
      ),
    );
    return null;
  }
}

Future<http.Response> _httpGet(
  Uri uri, {
  http.Client? client,
  required Duration timeout,
}) async {
  if (client != null) {
    return client.get(uri).timeout(timeout);
  }
  final localClient = http.Client();
  try {
    return await localClient.get(uri).timeout(timeout);
  } finally {
    localClient.close();
  }
}
