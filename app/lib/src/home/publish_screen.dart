import "dart:async";
import "dart:io";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart";
import "../../theme/app_colors.dart";
import "../utils/geo.dart";
import "../utils/location.dart";
import "../utils/postcode_lookup.dart";
import "../analytics/app_analytics.dart";
import "../models/item.dart";
import "../models/monetization.dart";
import "../monetization/monetization_service.dart";
import "../widgets/map_picker.dart";
import "../widgets/motion/pressable_scale.dart";
import "../testing/test_keys.dart";
import "item_detail_screen.dart";

typedef PublishLocationBootstrapLoader =
    Future<LocationBootstrapResult> Function();
typedef PublishReversePostcodeLookup =
    Future<String?> Function(LatLng location);

class PublishScreen extends StatefulWidget {
  const PublishScreen({
    super.key,
    this.locationBootstrapLoader,
    this.reversePostcodeLookup,
    this.enableBootstrapAnalytics = true,
  });

  final PublishLocationBootstrapLoader? locationBootstrapLoader;
  final PublishReversePostcodeLookup? reversePostcodeLookup;
  final bool enableBootstrapAnalytics;

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  LatLng? _location;
  LocationBootstrapResult _locationBootstrap =
      const LocationBootstrapResult.loading();
  ContactPreference _contactPreference = ContactPreference.both;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bootstrapLocation();
  }

  bool get _isLocationResolving =>
      _location == null &&
      _locationBootstrap.status == LocationBootstrapStatus.loading;

  bool get _isLocationUnavailable =>
      _location == null && _locationBootstrap.isUnavailable;

  Future<void> _bootstrapLocation() async {
    if (mounted) {
      setState(() {
        _locationBootstrap = const LocationBootstrapResult.loading();
        _postcodeController.clear();
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
        _location = null;
        _locationBootstrap = result;
        _postcodeController.clear();
      });
      return;
    }

    final current = result.location!;
    final reverseLookup = widget.reversePostcodeLookup ?? reverseUkPostcode;
    var postcode = "";
    try {
      postcode = (await reverseLookup(current)) ?? "";
    } catch (_) {}

    if (!mounted) {
      return;
    }
    setState(() {
      _location = current;
      _locationBootstrap = result;
      _postcodeController.text = postcode;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (file == null) {
        return;
      }
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await file.readAsBytes();
      }
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
    } on PlatformException catch (error) {
      _showError(error.message ?? "Photo permission denied.");
    } catch (_) {
      _showError("Could not access the gallery.");
    }
  }

  Future<void> _pickLocation() async {
    final selected = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapPicker(
          initialCenter: _location ?? defaultCenter,
          initialPostcode: _postcodeController.text.trim().isEmpty
              ? null
              : _postcodeController.text.trim(),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _location = selected.location;
        _locationBootstrap = LocationBootstrapResult.resolved(
          selected.location,
        );
        if (selected.postcode != null && selected.postcode!.isNotEmpty) {
          _postcodeController.text = selected.postcode!;
        } else {
          _postcodeController.clear();
        }
      });
    }
  }

  Future<void> _logLocationBootstrap(LocationBootstrapResult result) async {
    if (!widget.enableBootstrapAnalytics) {
      return;
    }
    await AppAnalytics.logEvent(
      name: "location_bootstrap",
      parameters: {
        "screen": "publish",
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
        "screen": "publish",
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

  Widget _buildLocationStatus(BuildContext context) {
    if (_isLocationResolving) {
      return Container(
        key: const ValueKey(TestKeys.publishLocationStatus),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.sageSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Finding your current area...",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isLocationUnavailable) {
      return const SizedBox.shrink();
    }

    final reason = _locationBootstrap.reason!;
    return Container(
      key: const ValueKey(TestKeys.publishLocationStatus),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locationBootstrapFailureMessage(reason),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey(TestKeys.publishLocationAction),
            onPressed: _handleLocationUnavailableAction,
            child: Text(locationBootstrapFailureActionLabel(reason)),
          ),
        ],
      ),
    );
  }

  Future<void> _publish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("You need to sign in.");
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final area = _areaController.text.trim();
    if (title.isEmpty || description.isEmpty || area.isEmpty) {
      _showError("Enter a title, description, and approximate area.");
      return;
    }
    if (_imageFile == null) {
      _showError("Select a photo.");
      return;
    }
    if (_location == null) {
      _showError("Select a location.");
      return;
    }

    if (!await _checkPublishSoftLimit()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection("items").doc();
      final storageRef = FirebaseStorage.instance.ref().child(
        "itemPhotos/${user.uid}/${docRef.id}/photo.jpg",
      );
      final photoPath = storageRef.fullPath;
      if (kIsWeb) {
        final bytes = _imageBytes;
        if (bytes == null) {
          throw Exception("Missing image bytes");
        }
        await storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: _imageFile?.mimeType ?? "image/jpeg",
            cacheControl: "public,max-age=31536000",
          ),
        );
      } else {
        final file = File(_imageFile!.path);
        await storageRef.putFile(
          file,
          SettableMetadata(
            contentType: _imageFile?.mimeType ?? "image/jpeg",
            cacheControl: "public,max-age=31536000",
          ),
        );
      }
      final photoUrl = await storageRef.getDownloadURL();

      final geohash = encodeGeohash(
        _location!.latitude,
        _location!.longitude,
        precision: 9,
      );

      await docRef.set({
        "ownerId": user.uid,
        "title": title,
        "description": description,
        "photoUrl": photoUrl,
        "photoPath": photoPath,
        "createdAt": FieldValue.serverTimestamp(),
        "status": "available",
        "contactPreference": contactPreferenceToString(_contactPreference),
        "location": {
          "lat": _location!.latitude,
          "lng": _location!.longitude,
          "geohash": geohash,
          "approxAreaText": area,
        },
      });
      await AppAnalytics.logEvent(
        name: "publish_item",
        parameters: {"itemId": docRef.id},
      );

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _areaController.clear();
      _postcodeController.clear();
      setState(() {
        _imageFile = null;
        _location = null;
        _contactPreference = ContactPreference.both;
      });
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: docRef.id)),
      );
    } catch (error) {
      _showError("Could not publish.");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkPublishSoftLimit() async {
    try {
      final status = await MonetizationService.getStatus();
      final features = status.features;
      if (!features.monetizationEnabled || !features.enforcePublishLimit) {
        return true;
      }
      if (status.canPublish) {
        return true;
      }
      await AppAnalytics.logEvent(
        name: "monetization_flag_state",
        parameters: features.analyticsParams(
          source: paywallContextToWire(PaywallContext.publish),
        ),
      );
      await AppAnalytics.logEvent(
        name: "paywall_shown",
        parameters: {
          "context": paywallContextToWire(PaywallContext.publish),
          "over_by": status.publishOverBy,
          "tier": status.isMonthlySupporter ? "supporter_monthly" : "free",
          ...features.analyticsParams(
            source: paywallContextToWire(PaywallContext.publish),
          ),
        },
      );
      if (!mounted) {
        return false;
      }
      final decision = await showSoftPaywallSheet(
        context: context,
        paywallContext: PaywallContext.publish,
        status: status,
      );
      if (decision == SoftPaywallDecision.continueFree) {
        await AppAnalytics.logEvent(
          name: "paywall_continue_free",
          parameters: {"context": paywallContextToWire(PaywallContext.publish)},
        );
        return true;
      }
      return false;
    } catch (_) {
      // Soft paywall must never block core behavior on errors.
      return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Publish")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _areaController,
                    decoration: const InputDecoration(
                      labelText: "Approximate area",
                      helperText: "Shown to other users.",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "How can people contact you?",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("Email only"),
                  selected: _contactPreference == ContactPreference.email,
                  onSelected: (_) {
                    setState(() {
                      _contactPreference = ContactPreference.email;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text("Chat only"),
                  selected: _contactPreference == ContactPreference.chat,
                  onSelected: (_) {
                    setState(() {
                      _contactPreference = ContactPreference.chat;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text("Email + Chat"),
                  selected: _contactPreference == ContactPreference.both,
                  onSelected: (_) {
                    setState(() {
                      _contactPreference = ContactPreference.both;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLocationStatus(context),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postcodeController,
                    decoration: InputDecoration(
                      labelText: "Location (postcode)",
                      helperText: _isLocationResolving
                          ? "Finding your current area."
                          : (_isLocationUnavailable
                                ? "Current location unavailable. Choose a location manually."
                                : "Derived from device location."),
                    ),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PressableScale(
              child: Card(
                child: ListTile(
                  key: const ValueKey(TestKeys.publishLocationTile),
                  onTap: _isLocationResolving ? null : _pickLocation,
                  leading: const Icon(Icons.map_outlined),
                  trailing: _isLocationResolving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  title: Text(
                    _location == null
                        ? (_isLocationResolving
                              ? "Finding location..."
                              : "Select location")
                        : "Change location",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PressableScale(
              child: InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(16),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _imageFile != null
                        ? (kIsWeb
                              ? Image.memory(
                                  _imageBytes ?? Uint8List(0),
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_imageFile!.path),
                                  fit: BoxFit.cover,
                                ))
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Select photo",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tap to choose from gallery",
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PressableScale(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _publish,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Publish"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
