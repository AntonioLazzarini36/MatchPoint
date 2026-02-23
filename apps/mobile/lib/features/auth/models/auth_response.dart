class AuthResponse {
  final String userId;
  final String accessToken;

  AuthResponse({required this.userId, required this.accessToken});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'],
      accessToken: json['accessToken'],
    );
  }
}
