import '../../../features/discovery/models/sport.dart';

class ProfileHeaderData {
  final String displayName;
  final int? age;
  final String? city;
  final String? bio;
  final List<String> photos;
  final List<Sport> sports;

  const ProfileHeaderData({
    required this.displayName,
    required this.photos,
    required this.sports,
    this.age,
    this.city,
    this.bio,
  });

  String get title {
    final a = age;
    return a == null ? displayName : '$displayName, $a';
  }

  String get subtitle {
    final c = (city ?? '').trim();
    return c.isEmpty ? '—' : c;
  }

  String? get mainPhoto => photos.isNotEmpty ? photos.first : null;
}