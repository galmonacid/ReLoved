import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "../../theme/app_colors.dart";
import "../analytics/app_analytics.dart";
import "../models/item.dart";
import "../utils/geo.dart";
import "../utils/location.dart";
import "../utils/postcode_lookup.dart";
import "../widgets/item_image.dart";
import "../widgets/map_picker.dart";
import "../widgets/motion/pressable_scale.dart";
import "../testing/test_keys.dart";
import "item_detail_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  LatLng _center = defaultCenter;
  double _radiusMiles = 3;
  String _query = "";
  String? _centerLabel;
  final TextEditingController _searchController = TextEditingController();
  bool _hasAnimatedResultsIn = false;
  bool _resultsVisible = false;
  static const double _kmPerMile = 1.60934;

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    final current = await getCurrentLocationOrDefault();
    if (!mounted) return;
    setState(() {
      _center = current;
    });
    final postcode = await reverseUkPostcode(current);
    if (!mounted) return;
    setState(() {
      _centerLabel = postcode;
    });
  }

  Future<void> _pickCenter() async {
    final selected = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) =>
            MapPicker(initialCenter: _center, initialPostcode: _centerLabel),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _center = selected.location;
        _centerLabel = selected.postcode;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setRadius(double selectedRadius) {
    setState(() {
      _radiusMiles = selectedRadius;
    });
    AppAnalytics.logEvent(
      name: "search_radius_change",
      parameters: {
        "radiusMiles": selectedRadius,
        "radiusKm": selectedRadius * _kmPerMile,
      },
    );
  }

  Widget _buildResultsSliver(BuildContext context, List<Item> items) {
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text("No items in this radius.")),
      );
    }
    const horizontalPadding = 16.0;
    const crossSpacing = 12.0;
    const minTileWidth = 220.0;
    final screenWidth = MediaQuery.of(context).size.width;
    var crossAxisCount =
        ((screenWidth - (horizontalPadding * 2) + crossSpacing) /
                (minTileWidth + crossSpacing))
            .floor();
    if (crossAxisCount < 2) {
      crossAxisCount = 2;
    }
    final tileWidth =
        (screenWidth -
            (horizontalPadding * 2) -
            ((crossAxisCount - 1) * crossSpacing)) /
        crossAxisCount;
    final tileHeight = (tileWidth * 0.75) + 96;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      sliver: SliverAnimatedOpacity(
        opacity: _resultsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = items[index];
            return PressableScale(
              child: Card(
                key: ValueKey(TestKeys.searchItemCard(item.id)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    AppAnalytics.logEvent(
                      name: "select_item",
                      parameters: {"itemId": item.id},
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(itemId: item.id),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ItemImage(
                            photoUrl: item.photoUrl,
                            photoPath: item.photoPath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            semanticLabel: "Foto de ${item.title}",
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.location.approxAreaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: items.length),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: tileHeight,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey(TestKeys.searchScreen),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("items")
            .orderBy("createdAt", descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          final hasData = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
          final items = hasData
              ? snapshot.data!.docs
                    .map(Item.fromDoc)
                    .where((item) => item.status == "available")
                    .where((item) {
                      if (_query.isEmpty) return true;
                      final haystack = "${item.title} ${item.description}"
                          .toLowerCase();
                      return haystack.contains(_query);
                    })
                    .where((item) {
                      final distanceKmValue = distanceKm(
                        _center,
                        item.location.toLatLng(),
                      );
                      return distanceKmValue <= _radiusMiles * _kmPerMile;
                    })
                    .toList()
              : <Item>[];
          if (!_hasAnimatedResultsIn && items.isNotEmpty) {
            _hasAnimatedResultsIn = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _resultsVisible = true;
                });
              }
            });
          } else if (_hasAnimatedResultsIn) {
            _resultsVisible = true;
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                backgroundColor: AppColors.sageSoft,
                surfaceTintColor: AppColors.sageSoft,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(124),
                  child: Container(
                    color: AppColors.sageSoft,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 52,
                          child: SearchBar(
                            key: const ValueKey(TestKeys.searchKeywordField),
                            controller: _searchController,
                            hintText: "Search by keyword",
                            elevation: WidgetStateProperty.all(0),
                            backgroundColor: WidgetStateProperty.all(
                              AppColors.sageSoft,
                            ),
                            leading: const Icon(Icons.search),
                            trailing: [
                              if (_query.isNotEmpty)
                                IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _query = "";
                                    });
                                  },
                                  tooltip: "Clear",
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _query = value.trim().toLowerCase();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ActionChip(
                                avatar: const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                side: BorderSide.none,
                                backgroundColor: Colors.white,
                                label: Text(
                                  _centerLabel == null
                                      ? "Select location"
                                      : _centerLabel!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: _pickCenter,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text("3 mi "),
                              selected: _radiusMiles == 3,
                              showCheckmark: false,
                              side: BorderSide.none,
                              backgroundColor: Colors.white,
                              selectedColor: AppColors.primary,
                              labelStyle: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _radiusMiles == 3
                                        ? Colors.white
                                        : AppColors.body,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                  ),
                              onSelected: (_) => _setRadius(3),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text("10 mi"),
                              selected: _radiusMiles == 10,
                              showCheckmark: false,
                              side: BorderSide.none,
                              backgroundColor: Colors.white,
                              selectedColor: AppColors.primary,
                              labelStyle: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _radiusMiles == 10
                                        ? Colors.white
                                        : AppColors.body,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                  ),
                              onSelected: (_) => _setRadius(10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Could not load items.")),
                )
              else if (!hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("No items available.")),
                )
              else
                _buildResultsSliver(context, items),
            ],
          );
        },
      ),
    );
  }
}
