import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../models/update_profile_request.dart';
import '../models/profile.dart';
import '../../discovery/models/discover_profile.dart';

class ProfileService {
  final ApiClient api;
  ProfileService(this.api);

  Future<void> updateProfile(UpdateProfileRequest request) async {
    final res = await api.patch(
      '/me/profile',
      body: request.toJson(),
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Profile update failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<MeResponse> getMe() async {
    final res = await api.get('/me', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GetMe failed: ${res.statusCode} ${res.body}');
    }

    return MeResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<DiscoverProfile> getUserProfile(String userId) async {
    final res = await api.get('/users/$userId/profile', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GetUserProfile failed: ${res.statusCode} ${res.body}');
    }

    return DiscoverProfile.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
