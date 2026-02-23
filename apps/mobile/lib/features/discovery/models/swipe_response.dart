class SwipeResponse {
  final bool match;
  final String? matchId;

  SwipeResponse({required this.match, this.matchId});

  factory SwipeResponse.fromJson(Map<String, dynamic> json) {
    return SwipeResponse(
      match: json['match'] == true,
      matchId: json['matchId']?.toString(),
    );
  }
}
