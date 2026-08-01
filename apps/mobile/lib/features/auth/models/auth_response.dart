class AuthResponse {
  final String userId;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'],
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }
}
