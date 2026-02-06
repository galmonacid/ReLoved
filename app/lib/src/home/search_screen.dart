import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "../models/item.dart";
import "../utils/geo.dart";
import "../utils/location.dart";
import "../utils/postcode_lookup.dart";
import "../widgets/item_image.dart";
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
  String _query = "";
  String? _centerLabel;
  bool _isLookingUpPostcode = false;
  final _postcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  @override
  void dispose() {
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialLocation() async {
    final current = await getCurrentLocationOrDefault();
    if (!mounted) return;
    setState(() {
      _center = current;
    });
  }

  Future<void> _pickCenter() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPicker(initialCenter: _center),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _center = selected;
        _centerLabel = null;
      });
    }
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
        _center = result.location;
        _centerLabel = result.postcode;
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
        title: const Text("Search"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _centerLabel == null
                        ? "Location: ${_center.latitude.toStringAsFixed(3)}, ${_center.longitude.toStringAsFixed(3)}"
                        : "Location: ${_centerLabel!}",
                  ),
                ),
                TextButton(
                  onPressed: _pickCenter,
                  child: const Text("Change"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text("Radius:"),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text("5 km"),
                  selected: _radiusKm == 5,
                  onSelected: (_) {
                    setState(() {
                      _radiusKm = 5;
                    });
                    FirebaseAnalytics.instance.logEvent(
                      name: "search_radius_change",
                      parameters: {"radiusKm": 5},
                    );
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
                    FirebaseAnalytics.instance.logEvent(
                      name: "search_radius_change",
                      parameters: {"radiusKm": 20},
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search by keyword",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
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
                    child: Text("Could not load items."),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No items available."));
                }
                final items = snapshot.data!.docs
                    .map(Item.fromDoc)
                    .where((item) => item.status == "available")
                    .where((item) {
                      if (_query.isEmpty) return true;
                      final haystack =
                          "${item.title} ${item.description}".toLowerCase();
                      return haystack.contains(_query);
                    })
                    .where((item) {
                  final distance = distanceKm(_center, item.location.toLatLng());
                  return distance <= _radiusKm;
                }).toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Text("No items in this radius."),
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
                        child: ItemImage(
                          photoUrl: item.photoUrl,
                          photoPath: item.photoPath,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          semanticLabel: "Foto de ${item.title}",
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.location.approxAreaText),
                      onTap: () {
                        FirebaseAnalytics.instance.logEvent(
                          name: "select_item",
                          parameters: {"itemId": item.id},
                        );
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
