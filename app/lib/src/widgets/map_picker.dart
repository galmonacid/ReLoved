import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../../theme/app_colors.dart";
import "../analytics/app_analytics.dart";
import "motion/pressable_scale.dart";
import "../utils/postcode_lookup.dart";

class MapPickerResult {
  const MapPickerResult({required this.location, this.postcode});

  final LatLng location;
  final String? postcode;
}

class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    required this.initialCenter,
    this.initialPostcode,
    this.postcodeLookup,
    this.reversePostcodeLookup,
    this.enableAnalytics = true,
  });

  final LatLng initialCenter;
  final String? initialPostcode;
  final Future<PostcodeResult?> Function(String postcode)? postcodeLookup;
  final Future<String?> Function(LatLng location)? reversePostcodeLookup;
  final bool enableAnalytics;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final MapController _mapController = MapController();
  late LatLng _selected;
  String? _postcodeLabel;
  bool _isLookingUpPostcode = false;
  final _postcodeController = TextEditingController();
  Timer? _reverseLookupTimer;
  int _activeReverseLookupRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
    _postcodeLabel = widget.initialPostcode;
  }

  @override
  void dispose() {
    _mapController.dispose();
    _postcodeController.dispose();
    _reverseLookupTimer?.cancel();
    super.dispose();
  }

  Future<void> _lookupPostcode() async {
    final postcode = normalizeUkPostcode(_postcodeController.text);
    if (postcode.isEmpty) {
      _showError("Enter a postcode.");
      return;
    }
    setState(() {
      _isLookingUpPostcode = true;
    });
    try {
      _activeReverseLookupRequestId += 1;
      final result = await _lookupPostcodeWithInstrumentation(postcode);
      if (result == null) {
        _showError("Could not look up the postcode.");
        return;
      }
      if (!mounted) return;
      setState(() {
        _selected = result.location;
        _postcodeLabel = result.postcode;
      });
      _mapController.move(result.location, 13);
    } catch (_) {
      _showError("Could not look up the postcode.");
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUpPostcode = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reverseLookupPostcode(LatLng location) async {
    final requestId = ++_activeReverseLookupRequestId;
    _reverseLookupTimer?.cancel();
    _reverseLookupTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || requestId != _activeReverseLookupRequestId) return;
      setState(() {
        _isLookingUpPostcode = true;
      });
      try {
        final postcode = await _reverseLookupWithInstrumentation(location);
        if (!mounted || requestId != _activeReverseLookupRequestId) return;
        setState(() {
          _postcodeLabel = postcode;
        });
      } catch (_) {
        if (!mounted || requestId != _activeReverseLookupRequestId) return;
        setState(() {
          _postcodeLabel = null;
        });
      } finally {
        if (mounted && requestId == _activeReverseLookupRequestId) {
          setState(() {
            _isLookingUpPostcode = false;
          });
        }
      }
    });
  }

  Future<PostcodeResult?> _lookupPostcodeWithInstrumentation(
    String postcode,
  ) async {
    final lookup = widget.postcodeLookup;
    if (lookup == null) {
      return lookupUkPostcode(
        postcode,
        onStep: (step) => _handleLookupStep(phase: "postcode_lookup", step: step),
      );
    }
    unawaited(_logLocationStep(phase: "postcode_lookup", status: "start"));
    final stopwatch = Stopwatch()..start();
    try {
      final result = await lookup(postcode);
      unawaited(
        _logLocationStep(
          phase: "postcode_lookup",
          status: result == null ? "empty" : "success",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: result == null ? "no_result" : null,
        ),
      );
      return result;
    } catch (error, stackTrace) {
      unawaited(
        _logLocationStep(
          phase: "postcode_lookup",
          status: "error",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "exception",
          recordNonFatal: true,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<String?> _reverseLookupWithInstrumentation(LatLng location) async {
    final reverseLookup = widget.reversePostcodeLookup;
    if (reverseLookup == null) {
      return reverseUkPostcode(
        location,
        onStep: (step) => _handleLookupStep(phase: "reverse_postcode", step: step),
      );
    }
    unawaited(_logLocationStep(phase: "reverse_postcode", status: "start"));
    final stopwatch = Stopwatch()..start();
    try {
      final postcode = await reverseLookup(location);
      unawaited(
        _logLocationStep(
          phase: "reverse_postcode",
          status: postcode == null || postcode.isEmpty ? "empty" : "success",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: postcode == null || postcode.isEmpty ? "no_result" : null,
        ),
      );
      return postcode;
    } catch (error, stackTrace) {
      unawaited(
        _logLocationStep(
          phase: "reverse_postcode",
          status: "error",
          elapsedMs: stopwatch.elapsedMilliseconds,
          reason: "exception",
          recordNonFatal: true,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  void _handleLookupStep({
    required String phase,
    required PostcodeLookupStep step,
  }) {
    unawaited(
      _logLocationStep(
        phase: phase,
        status: step.status,
        elapsedMs: step.elapsedMs,
        reason: step.reason,
        recordNonFatal: step.status == "timeout" || step.status == "error",
      ),
    );
  }

  Future<void> _logLocationStep({
    required String phase,
    required String status,
    int? elapsedMs,
    String? reason,
    bool recordNonFatal = false,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    if (!widget.enableAnalytics) {
      return;
    }
    await AppAnalytics.logLocationBootstrapStep(
      screen: "map_picker",
      phase: phase,
      status: status,
      elapsedMs: elapsedMs,
      reason: reason,
    );
    if (!recordNonFatal) {
      return;
    }
    await AppAnalytics.recordNonFatal(
      reason: "map_picker_${phase}_$status",
      error: error,
      stackTrace: stackTrace,
      context: {
        "screen": "map_picker",
        "phase": phase,
        "status": status,
        if (elapsedMs != null) "elapsed_ms": elapsedMs,
        if (reason != null) "reason": reason,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select location")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _postcodeController,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) {
                if (!_isLookingUpPostcode) {
                  _lookupPostcode();
                }
              },
              decoration: InputDecoration(
                hintText: "Search by postcode",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLookingUpPostcode
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _lookupPostcode,
                        icon: const Icon(Icons.search),
                        tooltip: "Search",
                      ),
                fillColor: AppColors.sageSoft,
                filled: true,
              ),
            ),
          ),
          if (_postcodeLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Current postcode: ${_postcodeLabel!}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: 13,
                onTap: (_, point) {
                  setState(() {
                    _selected = point;
                    _postcodeLabel = null;
                  });
                  _reverseLookupPostcode(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.greenhilledge.reloved",
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.error,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: PressableScale(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      MapPickerResult(
                        location: _selected,
                        postcode: _postcodeLabel,
                      ),
                    );
                  },
                  child: const Text("Confirm location"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
