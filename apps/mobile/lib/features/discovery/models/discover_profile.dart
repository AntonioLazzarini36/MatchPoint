import 'sport.dart';

class DiscoverProfile {
  final String userId;
  final String displayName;
  final DateTime birthDate;
  final String? city;
  final String? bio;
  final List<String> photos;
  final List<Sport> sports;

  DiscoverProfile({
    required this.userId,
    required this.displayName,
    required this.birthDate,
    required this.photos,
    required this.sports,
    this.city,
    this.bio,
  });

  int get age {
    final now = DateTime.now();
    int a = now.year - birthDate.year;
    final hadBirthday =
        (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) a--;
    return a;
  }

  String? get mainPhoto => photos.isNotEmpty ? photos.first : null;

  factory DiscoverProfile.fromJson(Map<String, dynamic> json) {
    // Soporta dos formas comunes:
    // A) { userId, displayName, birthDate, city, bio, photos, sports }
    // B) { userId, profile: { ... } }
    final Map<String, dynamic> p = (json['profile'] is Map<String, dynamic>)
        ? (json['profile'] as Map<String, dynamic>)
        : json;

    return DiscoverProfile(
      userId: (json['userId'] ?? p['userId'] ?? p['id']).toString(),
      displayName: (p['displayName'] ?? '').toString(),
      birthDate: DateTime.parse(p['birthDate'].toString()),
      city: p['city']?.toString(),
      bio: p['bio']?.toString(),
      photos: (p['photos'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      sports: (p['sports'] as List<dynamic>? ?? const [])
          .map((e) => SportApi.fromApi(e.toString()))
          .toList(),
    );
  }
}
