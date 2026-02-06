import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../utils/postcode_lookup.dart";

class MapPickerResult {
  const MapPickerResult({
    required this.location,
    this.postcode,
  });

  final LatLng location;
  final String? postcode;
}

class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    required this.initialCenter,
  });

  final LatLng initialCenter;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late LatLng _selected;
  String? _postcodeLabel;
  bool _isLookingUpPostcode = false;
  final _postcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
  }

  @override
  void dispose() {
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _lookupPostcode() async {
    final postcode = _postcodeController.text.trim();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select location"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postcodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Search by postcode",
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLookingUpPostcode ? null : _lookupPostcode,
                  child: _isLookingUpPostcode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Search"),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: 13,
                onTap: (_, point) {
                  setState(() {
                    _selected = point;
                    _postcodeLabel = null;
                  });
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
                        color: Colors.red,
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
        ],
      ),
    );
  }
}
