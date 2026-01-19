import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

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

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar ubicacion"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 13,
              onTap: (_, point) {
                setState(() {
                  _selected = point;
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
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_selected);
              },
              child: const Text("Confirmar ubicacion"),
            ),
          ),
        ],
      ),
    );
  }
}
