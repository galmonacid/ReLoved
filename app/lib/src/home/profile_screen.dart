import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

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
                    final avg = ratingSnapshot.data?["avg"] as double? ?? 0.0;
                    final count = ratingSnapshot.data?["count"] as int? ?? 0;
                    return Text(
                      "Valoracion: ${avg.toStringAsFixed(1)} ($count votos)",
                    );
                  },
                ),
                const Spacer(),
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
