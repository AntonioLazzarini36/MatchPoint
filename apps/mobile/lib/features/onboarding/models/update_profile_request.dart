class UpdateProfileRequest {
  final String displayName;
  final String birthDate; // YYYY-MM-DD
  final String? city;
  final String? bio;
  final List<String> photos;
  final List<String> sports;

  UpdateProfileRequest({
    required this.displayName,
    required this.birthDate,
    this.city,
    this.bio,
    required this.photos,
    required this.sports,
  });

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'birthDate': birthDate,
        'city': city,
        'bio': bio,
        'photos': photos,
        'sports': sports,
      };
}