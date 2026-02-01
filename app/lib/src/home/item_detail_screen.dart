import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../models/item.dart";
import "contact_screen.dart";

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String status) async {
    setState(() {
      _isUpdating = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection("items")
          .doc(widget.itemId)
          .update({"status": status});
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
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
          title: const Text("Valorar intercambio"),
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
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text("Enviar"),
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gracias por tu valoracion.")),
    );
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
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Item no encontrado.")),
          );
        }
        final item = Item.fromDoc(snapshot.data!);
        final isOwner = user?.uid == item.ownerId;
        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.photoUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text("Estado: ${item.status}"),
                const SizedBox(height: 4),
                Text("Zona: ${item.location.approxAreaText}"),
                const SizedBox(height: 20),
                if (isOwner) ...[
                  const Text("Actualizar estado"),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: item.status,
                    items: const [
                      DropdownMenuItem(
                        value: "available",
                        child: Text("Disponible"),
                      ),
                      DropdownMenuItem(
                        value: "reserved",
                        child: Text("Reservado"),
                      ),
                      DropdownMenuItem(
                        value: "given",
                        child: Text("Entregado"),
                      ),
                    ],
                    onChanged: _isUpdating
                        ? null
                        : (value) {
                            if (value != null) {
                              _updateStatus(value);
                            }
                          },
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final sent = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ContactScreen(
                              itemId: item.id,
                              title: item.title,
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        if (sent == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Mensaje enviado.")),
                          );
                        }
                      },
                      child: const Text("Contactar"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (item.status == "given" && user != null)
                    FutureBuilder<bool>(
                      future: _hasRated(user.uid),
                      builder: (context, ratingSnapshot) {
                        final alreadyRated = ratingSnapshot.data ?? false;
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: alreadyRated
                                ? null
                                : () => _showRatingDialog(item),
                            child: Text(
                              alreadyRated ? "Ya valorado" : "Valorar",
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
