import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../analytics/app_analytics.dart";
import "../auth/auth_screen.dart";
import "../chat/chat_service.dart";
import "../models/item.dart";
import "../utils/share_utils.dart";
import "../widgets/item_image.dart";
import "../widgets/motion/pressable_scale.dart";
import "chat_thread_screen.dart";
import "contact_screen.dart";

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isUpdatingStatus = false;
  bool _isUpdatingContactPreference = false;

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

  String _contactPreferenceLabel(ContactPreference preference) {
    switch (preference) {
      case ContactPreference.email:
        return "Email only";
      case ContactPreference.chat:
        return "Chat only";
      case ContactPreference.both:
        return "Email + Chat";
    }
  }

  @override
  void initState() {
    super.initState();
    AppAnalytics.logEvent(
      name: "view_item",
      parameters: {"itemId": widget.itemId},
    );
  }

  Future<void> _updateStatus(String status) async {
    setState(() {
      _isUpdatingStatus = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection("items")
          .doc(widget.itemId)
          .update({"status": status});
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _updateContactPreference(ContactPreference preference) async {
    setState(() {
      _isUpdatingContactPreference = true;
    });
    try {
      await ChatService.setItemContactPreference(
        itemId: widget.itemId,
        contactPreference: preference,
      );
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingContactPreference = false;
        });
      }
    }
  }

  Future<bool> _hasRated(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("ratings")
        .where("fromUserId", isEqualTo: userId)
        .where("itemId", isEqualTo: widget.itemId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> _showRatingDialog(Item item) async {
    int selected = 5;
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rate exchange"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        selected = star;
                      });
                    },
                    icon: Icon(
                      Icons.star,
                      color: selected >= star ? Colors.orange : Colors.grey,
                    ),
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text("Send"),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection("ratings").add({
      "fromUserId": user.uid,
      "toUserId": item.ownerId,
      "itemId": item.id,
      "stars": result,
      "createdAt": FieldValue.serverTimestamp(),
    });
    await AppAnalytics.logEvent(
      name: "submit_rating",
      parameters: {"itemId": item.id, "stars": result},
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Thanks for your rating.")));
  }

  Future<User?> _ensureSignedIn() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      return current;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    return FirebaseAuth.instance.currentUser;
  }

  Future<void> _openChat(Item item) async {
    final user = await _ensureSignedIn();
    if (user == null || !mounted) {
      return;
    }

    try {
      await AppAnalytics.logEvent(
        name: "contact_channel_selected",
        parameters: {"itemId": item.id, "channel": "chat"},
      );
      final conversationId = await ChatService.upsertItemConversation(item.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(conversationId: conversationId),
        ),
      );
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _openEmailContact(Item item) async {
    final user = await _ensureSignedIn();
    if (user == null || !mounted) {
      return;
    }

    await AppAnalytics.logEvent(
      name: "contact_channel_selected",
      parameters: {"itemId": item.id, "channel": "email"},
    );
    if (!mounted) {
      return;
    }

    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContactScreen(itemId: item.id, title: item.title),
      ),
    );
    if (!mounted) {
      return;
    }
    if (sent == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Message sent.")));
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _contactSection(Item item) {
    final user = FirebaseAuth.instance.currentUser;
    if (item.status == "given") {
      return const Text("This item is no longer available.");
    }

    switch (item.contactPreference) {
      case ContactPreference.email:
        return SizedBox(
          width: double.infinity,
          child: PressableScale(
            child: ElevatedButton(
              onPressed: () => _openEmailContact(item),
              child: const Text("Contact by email"),
            ),
          ),
        );
      case ContactPreference.chat:
        return SizedBox(
          width: double.infinity,
          child: PressableScale(
            child: ElevatedButton(
              onPressed: () => _openChat(item),
              child: const Text("Open chat"),
            ),
          ),
        );
      case ContactPreference.both:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PressableScale(
              child: ElevatedButton(
                onPressed: () => _openChat(item),
                child: const Text("Open chat"),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openEmailContact(item),
              child: const Text("Contact by email"),
            ),
            if (user == null)
              Text(
                "Sign in to start chatting or email the donor.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("items")
          .doc(widget.itemId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Could not load the item.")),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("Item not found.")));
        }
        final item = Item.fromDoc(snapshot.data!);
        final isOwner = user?.uid == item.ownerId;
        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              IconButton(
                onPressed: () => shareItem(context, item),
                icon: const Icon(Icons.share),
                tooltip: "Share",
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ItemImage(
                    photoUrl: item.photoUrl,
                    photoPath: item.photoPath,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    semanticLabel: "Foto de ${item.title}",
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item.description),
                ],
                const SizedBox(height: 8),
                Text("Status: ${_statusLabel(item.status)}"),
                const SizedBox(height: 4),
                Text("Location: ${item.location.approxAreaText}"),
                const SizedBox(height: 4),
                Text(
                  "Contact: ${_contactPreferenceLabel(item.contactPreference)}",
                ),
                const SizedBox(height: 20),
                if (isOwner) ...[
                  const Text("Update status"),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: item.status,
                    items: const [
                      DropdownMenuItem(
                        value: "available",
                        child: Text("Available"),
                      ),
                      DropdownMenuItem(
                        value: "reserved",
                        child: Text("Reserved"),
                      ),
                      DropdownMenuItem(value: "given", child: Text("Given")),
                    ],
                    onChanged: _isUpdatingStatus
                        ? null
                        : (value) {
                            if (value != null) {
                              _updateStatus(value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  const Text("Contact preference"),
                  const SizedBox(height: 8),
                  DropdownButton<ContactPreference>(
                    value: item.contactPreference,
                    items: ContactPreference.values
                        .map(
                          (preference) => DropdownMenuItem<ContactPreference>(
                            value: preference,
                            child: Text(_contactPreferenceLabel(preference)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isUpdatingContactPreference
                        ? null
                        : (value) {
                            if (value != null) {
                              _updateContactPreference(value);
                            }
                          },
                  ),
                ] else ...[
                  _contactSection(item),
                  const SizedBox(height: 12),
                  if (item.status == "given" && user != null)
                    FutureBuilder<bool>(
                      future: _hasRated(user.uid),
                      builder: (context, ratingSnapshot) {
                        final alreadyRated = ratingSnapshot.data ?? false;
                        return SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: alreadyRated
                                ? null
                                : () => _showRatingDialog(item),
                            child: Text(
                              alreadyRated ? "Already rated" : "Rate",
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
