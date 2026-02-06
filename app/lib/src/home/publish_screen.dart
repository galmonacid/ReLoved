import "dart:io";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart";
import "../utils/geo.dart";
import "../utils/location.dart";
import "../utils/postcode_lookup.dart";
import "../widgets/map_picker.dart";
import "item_detail_screen.dart";

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  LatLng? _location;
  bool _isLoading = false;
  bool _isLookingUpPostcode = false;

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    final current = await getCurrentLocationOrDefault();
    if (!mounted) return;
    setState(() {
      _location = current;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
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
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPicker(initialCenter: _location ?? defaultCenter),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _location = selected;
      });
    }
  }

  Future<void> _lookupPostcode() async {
    final postcode = _areaController.text.trim();
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
        _location = result.location;
        _areaController.text = result.postcode;
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
      _showError("Enter a title, description, and postcode.");
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

    setState(() {
      _isLoading = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection("items").doc();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("itemPhotos/${user.uid}/${docRef.id}/photo.jpg");
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
        "location": {
          "lat": _location!.latitude,
          "lng": _location!.longitude,
          "geohash": geohash,
          "approxAreaText": area,
        },
      });
      await FirebaseAnalytics.instance.logEvent(
        name: "publish_item",
        parameters: {"itemId": docRef.id},
      );

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _areaController.clear();
      setState(() {
        _imageFile = null;
        _location = null;
      });
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(itemId: docRef.id),
        ),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Publish"),
      ),
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
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: "Postcode",
                        helperText: "Shown as approximate location.",
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: Text(_imageFile == null
                  ? "Select photo"
                  : "Change photo"),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.memory(
                        _imageBytes ?? Uint8List(0),
                        height: 180,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_imageFile!.path),
                        height: 180,
                        fit: BoxFit.cover,
                      ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(_location == null
                  ? "Select location"
                  : "Change location"),
            ),
            if (_location != null) ...[
              const SizedBox(height: 8),
              Text(
                "Location: ${_location!.latitude.toStringAsFixed(3)}, ${_location!.longitude.toStringAsFixed(3)}",
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _publish,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Publish"),
            ),
          ],
        ),
      ),
    );
  }
}
