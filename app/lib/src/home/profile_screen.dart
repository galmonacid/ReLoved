import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "../models/item.dart";
import "../widgets/item_image.dart";
import "item_detail_screen.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
      (accumulator, doc) =>
          accumulator + (doc.data()["stars"] as int? ?? 0),
    );
    return {"avg": total / snapshot.docs.length, "count": snapshot.docs.length};
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No has iniciado sesion.")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil"),
      ),
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
              return const Center(
                child: Text("No se pudo cargar el perfil."),
              );
            }
            final data = snapshot.data?.data() ?? {};
            final displayName = (data["displayName"] as String?) ?? "Usuario";
            final email = (data["email"] as String?) ?? user.email ?? "";
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(email),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: _loadRatings(user.uid),
                  builder: (context, ratingSnapshot) {
                    if (ratingSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Text("Cargando valoraciones...");
                    }
                    if (ratingSnapshot.hasError) {
                      return const Text("No se pudieron cargar valoraciones.");
                    }
                    final avg = ratingSnapshot.data?["avg"] as double? ?? 0.0;
                    final count = ratingSnapshot.data?["count"] as int? ?? 0;
                    return Text(
                      "Valoracion: ${avg.toStringAsFixed(1)} ($count votos)",
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  "Mis items",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
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
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (itemsSnapshot.hasError) {
                        return const Center(
                          child: Text("No se pudieron cargar tus items."),
                        );
                      }
                      final docs = itemsSnapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("Aun no has publicado items."),
                        );
                      }
                      final items = docs.map(Item.fromDoc).toList();
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
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
                            subtitle: Text("Estado: ${item.status}"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ItemDetailScreen(itemId: item.id),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text("Cerrar sesion"),
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
