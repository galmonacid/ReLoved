import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "../models/item.dart";
import "../utils/geo.dart";
import "../widgets/map_picker.dart";
import "item_detail_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  LatLng _center = defaultCenter;
  double _radiusKm = 5;

  Future<void> _pickCenter() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPicker(initialCenter: _center),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _center = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscar"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Centro: ${_center.latitude.toStringAsFixed(3)}, ${_center.longitude.toStringAsFixed(3)}",
                  ),
                ),
                TextButton(
                  onPressed: _pickCenter,
                  child: const Text("Cambiar"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text("Radio:"),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text("5 km"),
                  selected: _radiusKm == 5,
                  onSelected: (_) {
                    setState(() {
                      _radiusKm = 5;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("20 km"),
                  selected: _radiusKm == 20,
                  onSelected: (_) {
                    setState(() {
                      _radiusKm = 20;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("items")
                  .orderBy("createdAt", descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text("No se pudieron cargar los items."),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No hay items disponibles."));
                }
                final items = snapshot.data!.docs
                    .map(Item.fromDoc)
                    .where((item) => item.status == "available")
                    .where((item) {
                  final distance = distanceKm(_center, item.location.toLatLng());
                  return distance <= _radiusKm;
                }).toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Text("No hay items en este radio."),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item.photoUrl,
                          semanticLabel: "Foto de ${item.title}",
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.location.approxAreaText),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(itemId: item.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
