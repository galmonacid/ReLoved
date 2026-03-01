import "package:cloud_firestore/cloud_firestore.dart";
import "package:latlong2/latlong.dart";

enum ContactPreference { email, chat, both }

ContactPreference contactPreferenceFromString(String? value) {
  switch (value) {
    case "email":
      return ContactPreference.email;
    case "chat":
      return ContactPreference.chat;
    case "both":
      return ContactPreference.both;
    default:
      return ContactPreference.both;
  }
}

String contactPreferenceToString(ContactPreference preference) {
  switch (preference) {
    case ContactPreference.email:
      return "email";
    case ContactPreference.chat:
      return "chat";
    case ContactPreference.both:
      return "both";
  }
}

extension ContactPreferenceX on ContactPreference {
  bool get allowsEmail =>
      this == ContactPreference.email || this == ContactPreference.both;
  bool get allowsChat =>
      this == ContactPreference.chat || this == ContactPreference.both;
}

class ItemLocation {
  ItemLocation({
    required this.lat,
    required this.lng,
    required this.geohash,
    required this.approxAreaText,
  });

  final double lat;
  final double lng;
  final String geohash;
  final String approxAreaText;

  LatLng toLatLng() => LatLng(lat, lng);

  factory ItemLocation.fromMap(Map<String, dynamic> map) {
    return ItemLocation(
      lat: (map["lat"] as num?)?.toDouble() ?? 0,
      lng: (map["lng"] as num?)?.toDouble() ?? 0,
      geohash: (map["geohash"] as String?) ?? "",
      approxAreaText: (map["approxAreaText"] as String?) ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "lat": lat,
      "lng": lng,
      "geohash": geohash,
      "approxAreaText": approxAreaText,
    };
  }
}

class Item {
  Item({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.photoUrl,
    required this.photoPath,
    required this.createdAt,
    required this.status,
    required this.contactPreference,
    required this.location,
  });

  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String photoUrl;
  final String photoPath;
  final DateTime? createdAt;
  final String status;
  final ContactPreference contactPreference;
  final ItemLocation location;

  factory Item.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = data["createdAt"];
    return Item(
      id: doc.id,
      ownerId: (data["ownerId"] as String?) ?? "",
      title: (data["title"] as String?) ?? "",
      description: (data["description"] as String?) ?? "",
      photoUrl: (data["photoUrl"] as String?) ?? "",
      photoPath: (data["photoPath"] as String?) ?? "",
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      status: (data["status"] as String?) ?? "available",
      contactPreference: contactPreferenceFromString(
        data["contactPreference"] as String?,
      ),
      location: ItemLocation.fromMap(
        (data["location"] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}
