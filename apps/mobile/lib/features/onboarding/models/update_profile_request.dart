class UpdateProfileRequest {
  final String displayName;
  final String birthDate; // YYYY-MM-DD
  final String? city;
  final String? bio;
  final List<String> sports;

  UpdateProfileRequest({
    required this.displayName,
    required this.birthDate,
    this.city,
    this.bio,
    required this.sports,
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
  };
}
