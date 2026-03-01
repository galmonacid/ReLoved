import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";
import "../config/app_config.dart";
import "../models/item.dart";

Uri? buildShareUrl(String itemId) {
  if (!AppConfig.hasShareBaseUrl) {
    return null;
  }
  final base = Uri.parse(AppConfig.shareBaseUrl);
  if (base.scheme.isEmpty) {
    return null;
  }
  final basePath = base.path.endsWith("/")
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  final path = "${basePath.isEmpty ? "" : basePath}/items/$itemId";
  return base.replace(path: path);
}

Future<void> shareItem(BuildContext context, Item item) async {
  final url = buildShareUrl(item.id);
  final linkLine = url == null ? "" : "\n$url";
  final message = "Check out this item on ReLoved: ${item.title}$linkLine";
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
