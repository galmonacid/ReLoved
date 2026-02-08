import "package:flutter/material.dart";
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
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Configure the share URL in the build.")),
    );
    return;
  }
  final message = "Check out this item on ReLoved: ${item.title}\n$url";
  await Share.share(message, subject: "ReLoved item");
}
