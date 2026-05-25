import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";
import "../config/app_config.dart";
import "../models/item.dart";

Uri? buildShareUrl(String itemId) {
  if (!AppConfig.hasShareBaseUrl) {
    return null;
  }
  final trimmedItemId = itemId.trim();
  if (trimmedItemId.isEmpty) {
    return null;
  }
  final base = Uri.parse(AppConfig.shareBaseUrl);
  if (base.scheme.isEmpty) {
    return null;
  }
  final baseSegments = base.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  return base.replace(pathSegments: [...baseSegments, "items", trimmedItemId]);
}

String buildShareText(Item item) {
  final url = buildShareUrl(item.id);
  final linkLine = url == null ? "" : "\n$url";
  return "Check out this item on ReLoved: ${item.title}$linkLine";
}

Future<void> shareItem(BuildContext context, Item item) async {
  final message = buildShareText(item);
  try {
    final renderBox = context.findRenderObject() as RenderBox?;
    await Share.share(
      message,
      subject: "ReLoved item",
      sharePositionOrigin: renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size,
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Share unavailable. Link copied.")),
    );
  }
}

class ItemShareIconButton extends StatelessWidget {
  const ItemShareIconButton({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => shareItem(context, item),
      icon: const Icon(Icons.share),
      tooltip: "Share item",
    );
  }
}
