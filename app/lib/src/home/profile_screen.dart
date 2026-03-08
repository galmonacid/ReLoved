import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../../theme/app_colors.dart";
import "../config/app_config.dart";
import "../models/item.dart";
import "../monetization/monetization_service.dart";
import "../utils/share_utils.dart";
import "../widgets/item_image.dart";
import "../widgets/motion/fade_in_item.dart";
import "../widgets/motion/pressable_scale.dart";
import "about_support_screen.dart";
import "item_detail_screen.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case "available":
        return "Available";
      case "reserved":
        return "Reserved";
      case "given":
        return "Given";
      default:
        return status;
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    if (url.isEmpty) {
      _showConfigMissing(context);
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open the link.")));
    }
  }

  Future<void> _requestDeletion(BuildContext context, User user) async {
    if (!AppConfig.hasSupportEmail) {
      _showConfigMissing(context);
      return;
    }
    final uri = Uri(
      scheme: "mailto",
      path: AppConfig.supportEmail,
      queryParameters: {
        "subject": "Account deletion request",
        "body": "UID: ${user.uid}\nEmail: ${user.email ?? ""}",
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open the email app.")),
      );
    }
  }

  void _showConfigMissing(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Configure legal links and support in the build."),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadRatings(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("ratings")
        .where("toUserId", isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return {"avg": 0.0, "count": 0};
    }
    final total = snapshot.docs.fold<int>(
      0,
      (accumulator, doc) => accumulator + (doc.data()["stars"] as int? ?? 0),
    );
    return {"avg": total / snapshot.docs.length, "count": snapshot.docs.length};
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final supportUiFuture = MonetizationService.getStatus()
        .then((status) => status.supportUiEnabled)
        .catchError((_) => false);
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("You are not signed in.")),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Could not load profile."));
            }
            final data = snapshot.data?.data() ?? {};
            final displayName = (data["displayName"] as String?) ?? "Usuario";
            final email = (data["email"] as String?) ?? user.email ?? "";
            final initial = displayName.trim().isEmpty
                ? "U"
                : displayName.trim().substring(0, 1).toUpperCase();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.sageSoft,
                      foregroundColor: AppColors.primary,
                      child: Text(initial),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FutureBuilder<Map<String, dynamic>>(
                  future: _loadRatings(user.uid),
                  builder: (context, ratingSnapshot) {
                    if (ratingSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Text("Loading ratings...");
                    }
                    if (ratingSnapshot.hasError) {
                      return const Text("Could not load ratings.");
                    }
                    final avg = ratingSnapshot.data?["avg"] as double? ?? 0.0;
                    final count = ratingSnapshot.data?["count"] as int? ?? 0;
                    return Text(
                      "Rating: ${avg.toStringAsFixed(1)} ($count reviews)",
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  "My items",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection("items")
                        .where("ownerId", isEqualTo: user.uid)
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    builder: (context, itemsSnapshot) {
                      if (itemsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (itemsSnapshot.hasError) {
                        return const Center(
                          child: Text("Could not load your items."),
                        );
                      }
                      final docs = itemsSnapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("You have not published any items yet."),
                        );
                      }
                      final items = docs.map(Item.fromDoc).toList();
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return FadeInItem(
                            key: ValueKey("profile-${item.id}"),
                            delay: Duration(milliseconds: (index % 5) * 30),
                            child: PressableScale(
                              child: Card(
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: ItemImage(
                                      photoUrl: item.photoUrl,
                                      photoPath: item.photoPath,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      semanticLabel: "Foto de ${item.title}",
                                    ),
                                  ),
                                  title: Text(item.title),
                                  subtitle: Text(
                                    "Status: ${_statusLabel(item.status)}",
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            shareItem(context, item),
                                        icon: const Icon(Icons.share),
                                        tooltip: "Share",
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ItemDetailScreen(itemId: item.id),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Support & legal",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                PressableScale(
                  child: Card(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FutureBuilder<bool>(
                          future: supportUiFuture,
                          builder: (context, snapshot) {
                            if (snapshot.data != true) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text("About & support"),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AboutSupportScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          },
                        ),
                        ListTile(
                          title: const Text("Privacy policy"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _openUrl(context, AppConfig.privacyPolicyUrl),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text("Terms of service"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openUrl(context, AppConfig.termsUrl),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text("Request account deletion"),
                          trailing: const Icon(Icons.chevron_right),
                          textColor: AppColors.error,
                          iconColor: AppColors.error,
                          onTap: () => _requestDeletion(context, user),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text("Sign out"),
                          trailing: const Icon(Icons.chevron_right),
                          textColor: AppColors.error,
                          iconColor: AppColors.error,
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
