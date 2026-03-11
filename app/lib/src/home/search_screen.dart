import "dart:math" as math;

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
  static const double _kmPerMile = 1.60934;
  static const int _pageSize = 24;

  LatLng _center = defaultCenter;
  double _radiusMiles = 3;
  String _query = "";
  String? _centerLabel;
  final TextEditingController _searchController = TextEditingController();

  List<Item> _nearbyItems = const <Item>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreResults = false;
  bool _hasAnimatedResultsIn = false;
  bool _resultsVisible = false;
  String? _loadError;
  int _resultCap = _pageSize;
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _refreshSearch(resetPagination: true);
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    final current = await getCurrentLocationOrDefault();
    if (!mounted) {
      return;
    }
    setState(() {
      _center = current;
    });
    await _refreshSearch(resetPagination: true);

    final postcode = await reverseUkPostcode(current);
    if (!mounted) {
      return;
    }
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
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _center = selected.location;
      _centerLabel = selected.postcode;
    });
    await _refreshSearch(resetPagination: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSearch({required bool resetPagination}) async {
    if (resetPagination) {
      _resultCap = _pageSize;
    }
    final requestId = ++_activeRequestId;
    if (mounted) {
      setState(() {
        if (resetPagination) {
          _isLoading = true;
          _hasAnimatedResultsIn = false;
          _resultsVisible = false;
        } else {
          _isLoadingMore = true;
        }
        _loadError = null;
      });
    }

    try {
      final batch = await _fetchNearbyItems(
        center: _center,
        radiusKm: _radiusMiles * _kmPerMile,
        resultCap: _resultCap,
      );
      if (!mounted || requestId != _activeRequestId) {
        return;
      }

      setState(() {
        _nearbyItems = batch.items;
        _hasMoreResults = batch.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (!_hasAnimatedResultsIn && batch.items.isNotEmpty) {
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
    } catch (_) {
      if (!mounted || requestId != _activeRequestId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _loadError = "Could not load items.";
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMoreResults) {
      return;
    }
    setState(() {
      _resultCap += _pageSize;
    });
    await _refreshSearch(resetPagination: false);
  }

  Future<_SearchBatch> _fetchNearbyItems({
    required LatLng center,
    required double radiusKm,
    required int resultCap,
  }) async {
    final prefixes = geohashPrefixesForRadius(center, radiusKm);
    if (prefixes.isEmpty) {
      return const _SearchBatch(items: <Item>[], hasMore: false);
    }

    final targetFetchCount = resultCap + 12;
    final perPrefixLimit = math.max(
      12,
      ((targetFetchCount * 2) / prefixes.length).ceil(),
    );

    final snapshots = await Future.wait(
      prefixes.map((prefix) {
        return FirebaseFirestore.instance
            .collection("items")
            .where("status", isEqualTo: "available")
            .orderBy("location.geohash")
            .orderBy("createdAt", descending: true)
            .startAt([prefix])
            .endAt(["$prefix\uf8ff"])
            .limit(perPrefixLimit)
            .get();
      }),
    );

    final byId = <String, Item>{};
    var touchedPrefixLimit = false;
    for (final snapshot in snapshots) {
      if (snapshot.size == perPrefixLimit) {
        touchedPrefixLimit = true;
      }
      for (final doc in snapshot.docs) {
        final item = Item.fromDoc(doc);
        final distanceKmValue = distanceKm(center, item.location.toLatLng());
        if (distanceKmValue <= radiusKm) {
          byId[item.id] = item;
        }
      }
    }

    final items = byId.values.toList()
      ..sort(
        (a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      );

    final hasMore = items.length > resultCap || touchedPrefixLimit;
    return _SearchBatch(
      items: items.take(resultCap).toList(),
      hasMore: hasMore,
    );
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
    _refreshSearch(resetPagination: true);
  }

  List<Item> _visibleItems() {
    return _nearbyItems.where((item) {
      if (_query.isEmpty) {
        return true;
      }
      final haystack = "${item.title} ${item.description}".toLowerCase();
      return haystack.contains(_query);
    }).toList();
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

  Widget _buildLoadMoreSliver() {
    if (!_hasMoreResults) {
      return const SliverToBoxAdapter(child: SizedBox(height: 16));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Center(
          child: ElevatedButton(
            onPressed: _isLoadingMore ? null : _loadMore,
            child: _isLoadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Load more"),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems();
    return Scaffold(
      key: const ValueKey(TestKeys.searchScreen),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => _refreshSearch(resetPagination: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            if (_isLoading && _nearbyItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null && _nearbyItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(_loadError!)),
              )
            else
              _buildResultsSliver(context, items),
            if (!_isLoading && _loadError == null) _buildLoadMoreSliver(),
          ],
        ),
      ),
    );
  }
}

class _SearchBatch {
  const _SearchBatch({required this.items, required this.hasMore});

  final List<Item> items;
  final bool hasMore;
}
