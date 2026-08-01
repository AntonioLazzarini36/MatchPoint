class UpdateProfileRequest {
  final String displayName;
  final String birthDate; // YYYY-MM-DD
  final String? city;
  final String? bio;
  final List<String> sports;
  final double? latitude;
  final double? longitude;

  UpdateProfileRequest({
    required this.displayName,
    required this.birthDate,
    this.city,
    this.bio,
    required this.sports,
    this.latitude,
    this.longitude,
  });

  // Photos are managed only via ProfileService.uploadPhoto/deletePhoto
  // (POST/DELETE /me/photos) — the backend no longer accepts a `photos`
  // field here.
  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'birthDate': birthDate,
    'city': city,
    'bio': bio,
    'sports': sports,
    'latitude': latitude,
    'longitude': longitude,
  };
}
