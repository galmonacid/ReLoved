import "dart:io";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart";
import "../utils/geo.dart";
import "../widgets/map_picker.dart";
import "item_detail_screen.dart";

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final _titleController = TextEditingController();
  final _areaController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  LatLng? _location;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await file.readAsBytes();
      }
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
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

  Future<void> _publish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("Debes iniciar sesion.");
      return;
    }
    final title = _titleController.text.trim();
    final area = _areaController.text.trim();
    if (title.isEmpty || area.isEmpty) {
      _showError("Completa el titulo y la zona.");
      return;
    }
    if (_imageFile == null) {
      _showError("Selecciona una foto.");
      return;
    }
    if (_location == null) {
      _showError("Selecciona una ubicacion.");
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
      if (kIsWeb) {
        final bytes = _imageBytes;
        if (bytes == null) {
          throw Exception("Missing image bytes");
        }
        await storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: _imageFile?.mimeType ?? "image/jpeg",
          ),
        );
      } else {
        final file = File(_imageFile!.path);
        await storageRef.putFile(file);
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
        "photoUrl": photoUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "status": "available",
        "location": {
          "lat": _location!.latitude,
          "lng": _location!.longitude,
          "geohash": geohash,
          "approxAreaText": area,
        },
      });

      if (!mounted) return;
      _titleController.clear();
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
      _showError("No se pudo publicar.");
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
        title: const Text("Publicar"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Titulo"),
            ),
            TextField(
              controller: _areaController,
              decoration:
                  const InputDecoration(labelText: "Zona aproximada"),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: Text(_imageFile == null
                  ? "Seleccionar foto"
                  : "Cambiar foto"),
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
                  ? "Seleccionar ubicacion"
                  : "Cambiar ubicacion"),
            ),
            if (_location != null) ...[
              const SizedBox(height: 8),
              Text(
                "Ubicacion: ${_location!.latitude.toStringAsFixed(3)}, ${_location!.longitude.toStringAsFixed(3)}",
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
                  : const Text("Publicar"),
            ),
          ],
        ),
      ),
    );
  }
}
