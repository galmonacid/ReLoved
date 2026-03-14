import "dart:async";
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

typedef SearchLocationBootstrapLoader =
    Future<LocationBootstrapResult> Function();
typedef SearchReversePostcodeLookup = Future<String?> Function(LatLng location);
typedef SearchItemsLoader =
    Future<List<Item>> Function({
      required LatLng center,
      required double radiusKm,
      required int resultCap,
    });

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.locationBootstrapLoader,
    this.reversePostcodeLookup,
    this.searchItemsLoader,
    this.enableBootstrapAnalytics = true,
  });

  final SearchLocationBootstrapLoader? locationBootstrapLoader;
  final SearchReversePostcodeLookup? reversePostcodeLookup;
  final SearchItemsLoader? searchItemsLoader;
  final bool enableBootstrapAnalytics;

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
  LocationBootstrapResult _locationBootstrap =
      const LocationBootstrapResult.loading();
  final TextEditingController _searchController = TextEditingController();

  List<Item> _nearbyItems = const <Item>[];
  bool _hasSelectedCenter = false;
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
    _bootstrapLocation();
  }

  bool get _isLocationResolving =>
      !_hasSelectedCenter &&
      _locationBootstrap.status == LocationBootstrapStatus.loading;

  bool get _isLocationUnavailable =>
      !_hasSelectedCenter && _locationBootstrap.isUnavailable;

  Future<void> _bootstrapLocation() async {
    if (mounted) {
      setState(() {
        _locationBootstrap = const LocationBootstrapResult.loading();
        _isLoading = true;
        _loadError = null;
      });
    }

    final loader = widget.locationBootstrapLoader ?? bootstrapCurrentLocation;
    final result = await loader();
    unawaited(_logLocationBootstrap(result));
    if (!mounted) {
      return;
    }

    if (!result.isResolved) {
      setState(() {
        _locationBootstrap = result;
        _hasSelectedCenter = false;
        _centerLabel = null;
        _nearbyItems = const <Item>[];
        _hasMoreResults = false;
        _isLoading = false;
        _isLoadingMore = false;
        _hasAnimatedResultsIn = false;
        _resultsVisible = false;
        _loadError = null;
      });
      return;
    }

    final current = result.location!;
    final reverseLookup = widget.reversePostcodeLookup ?? reverseUkPostcode;
    var centerLabel = "Current area";
    try {
      final postcode = await reverseLookup(current);
      if (postcode != null && postcode.isNotEmpty) {
        centerLabel = postcode;
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }
    setState(() {
      _center = current;
      _centerLabel = centerLabel;
      _hasSelectedCenter = true;
      _locationBootstrap = result;
    });
    await _refreshSearch(resetPagination: true);
  }

  Future<void> _pickCenter() async {
    final selected = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPicker(
          initialCenter: _hasSelectedCenter ? _center : defaultCenter,
          initialPostcode: _centerLabel,
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _center = selected.location;
      _centerLabel = _resolvedManualCenterLabel(selected.postcode);
      _hasSelectedCenter = true;
      _locationBootstrap = LocationBootstrapResult.resolved(selected.location);
    });
    await _refreshSearch(resetPagination: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSearch({required bool resetPagination}) async {
    if (!_hasSelectedCenter) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      return;
    }
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
    final overrideLoader = widget.searchItemsLoader;
    if (overrideLoader != null) {
      final items = await overrideLoader(
        center: center,
        radiusKm: radiusKm,
        resultCap: resultCap,
      );
      return _SearchBatch(items: items, hasMore: false);
    }

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

  Future<void> _handleRefresh() async {
    if (_hasSelectedCenter) {
      await _refreshSearch(resetPagination: true);
      return;
    }
    await _bootstrapLocation();
  }

  String _resolvedManualCenterLabel(String? postcode) {
    final trimmed = postcode?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return "Selected area";
  }

  Future<void> _logLocationBootstrap(LocationBootstrapResult result) async {
    if (!widget.enableBootstrapAnalytics) {
      return;
    }
    await AppAnalytics.logEvent(
      name: "location_bootstrap",
      parameters: {
        "screen": "search",
        "status": result.analyticsStatus,
        if (result.analyticsReason != null) "reason": result.analyticsReason!,
      },
    );
  }

  Future<void> _logLocationAction({
    required String action,
    LocationBootstrapFailureReason? reason,
  }) async {
    if (!widget.enableBootstrapAnalytics) {
      return;
    }
    await AppAnalytics.logEvent(
      name: "location_bootstrap_action",
      parameters: {
        "screen": "search",
        "action": action,
        if (reason != null)
          "reason": locationBootstrapFailureReasonWire(reason),
      },
    );
  }

  Future<void> _handleLocationUnavailableAction() async {
    final reason = _locationBootstrap.reason;
    if (reason == null) {
      return;
    }
    if (locationBootstrapFailureNeedsSettings(reason)) {
      unawaited(_logLocationAction(action: "open_settings", reason: reason));
      await openLocationBootstrapSettings(reason: reason);
      return;
    }
    unawaited(_logLocationAction(action: "retry", reason: reason));
    await _bootstrapLocation();
  }

  String _locationChipLabel() {
    if (_hasSelectedCenter) {
      return _centerLabel ?? "Current area";
    }
    if (_isLocationResolving) {
      return "Finding location...";
    }
    final reason = _locationBootstrap.reason;
    if (reason == null) {
      return "Use current location";
    }
    return locationBootstrapFailureActionLabel(reason);
  }

  Widget _locationChipAvatar() {
    if (_isLocationResolving) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const Icon(
      Icons.location_on_outlined,
      size: 18,
      color: AppColors.primary,
    );
  }

  Widget _buildLocationUnavailableSliver(BuildContext context) {
    final reason = _locationBootstrap.reason;
    final message = reason == null
        ? "Location is unavailable."
        : locationBootstrapFailureMessage(reason);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 32),
              const SizedBox(height: 12),
              Text(
                message,
                key: const ValueKey(TestKeys.searchLocationState),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    key: const ValueKey(TestKeys.searchLocationAction),
                    onPressed: _handleLocationUnavailableAction,
                    child: Text(
                      reason == null
                          ? "Use current location"
                          : locationBootstrapFailureActionLabel(reason),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey(TestKeys.searchLocationManualAction),
                    onPressed: _pickCenter,
                    child: const Text("Choose on map"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        onRefresh: _handleRefresh,
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
                preferredSize: const Size.fromHeight(132),
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
                              key: const ValueKey(TestKeys.searchLocationChip),
                              avatar: _locationChipAvatar(),
                              side: BorderSide.none,
                              backgroundColor: Colors.white,
                              label: Text(
                                _locationChipLabel(),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: _isLocationResolving
                                  ? null
                                  : (_hasSelectedCenter
                                        ? _pickCenter
                                        : _handleLocationUnavailableAction),
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
            if (_isLocationResolving && _nearbyItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_isLocationUnavailable && _nearbyItems.isEmpty)
              _buildLocationUnavailableSliver(context)
            else if (_isLoading && _nearbyItems.isEmpty)
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
