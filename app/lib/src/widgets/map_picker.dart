import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../../theme/app_colors.dart";
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
  });

  final LatLng initialCenter;
  final String? initialPostcode;

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
      final result = await lookupUkPostcode(postcode);
      if (result == null) {
        _showError("Postcode not found.");
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
    _reverseLookupTimer?.cancel();
    _reverseLookupTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() {
        _isLookingUpPostcode = true;
      });
      try {
        final postcode = await reverseUkPostcode(location);
        if (!mounted) return;
        setState(() {
          _postcodeLabel = postcode;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _postcodeLabel = null;
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLookingUpPostcode = false;
          });
        }
      }
    });
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
