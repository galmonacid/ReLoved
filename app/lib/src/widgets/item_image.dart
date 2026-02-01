import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class ItemImage extends StatelessWidget {
  const ItemImage({
    super.key,
    required this.photoUrl,
    required this.width,
    required this.height,
    this.photoPath,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.maxBytes = 5 * 1024 * 1024,
  });

  final String photoUrl;
  final String? photoPath;
  final double width;
  final double height;
  final BoxFit fit;
  final String? semanticLabel;
  final int maxBytes;

  Reference? _resolveRef() {
    if (photoPath != null && photoPath!.isNotEmpty) {
      return FirebaseStorage.instance.ref(photoPath);
    }
    if (photoUrl.isEmpty) {
      return null;
    }
    try {
      return FirebaseStorage.instance.refFromURL(photoUrl);
    } catch (_) {
      return null;
    }
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported),
    );
  }

  Widget _networkImage(BuildContext context) {
    return Image.network(
      photoUrl,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return _placeholder(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isEmpty && (photoPath == null || photoPath!.isEmpty)) {
      return _placeholder(context);
    }

    if (kIsWeb) {
      final ref = _resolveRef();
      if (ref == null) {
        return _networkImage(context);
      }
      return FutureBuilder<Uint8List?>(
        future: ref.getData(maxBytes),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _placeholder(context);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _networkImage(context);
          }
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: semanticLabel,
          );
        },
      );
    }

    return _networkImage(context);
  }
}
