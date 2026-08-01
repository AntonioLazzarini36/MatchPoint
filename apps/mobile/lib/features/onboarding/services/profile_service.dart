import 'dart:convert';
import '../../../core/location/location_result.dart';
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

  /// Cambia la ubicación (Hinge-style, elegida a mano) en cualquier
  /// momento, no solo en el onboarding — manda un PATCH parcial (solo
  /// city/lat/lng) en vez de reusar `updateProfile`, que exige mandar
  /// displayName/birthDate/sports también.
  Future<void> updateLocation(LocationResult location) async {
    final res = await api.patch(
      '/me/profile',
      body: {
        'city': location.displayName,
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('UpdateLocation failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Solo el radio de descubrimiento por ahora (`distanceKm`) — editar
  /// edad/deportes/género buscados es una pantalla de filtros aparte, sin
  /// alcance definido todavía (ver status.md).
  Future<void> updateDiscoveryRadius(int distanceKm) async {
    final res = await api.patch(
      '/me/preferences',
      body: {'distanceKm': distanceKm},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'UpdatePreferences failed: ${res.statusCode} ${res.body}',
      );
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

  /// No bloquea ni borra el match — es solo constancia para revisión. Si
  /// además quieres cortar todo contacto, eso es un unmatch aparte.
  Future<void> reportUser(String userId, String reason) async {
    final res = await api.post(
      '/users/$userId/report',
      body: {'reason': reason},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('ReportUser failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Profile> uploadPhoto({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final res = await api.postMultipart(
      '/me/photos',
      fieldName: 'photo',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('UploadPhoto failed: ${res.statusCode} ${res.body}');
    }

    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Profile> deletePhoto(String url) async {
    final res = await api.delete(
      '/me/photos',
      body: {'url': url},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('DeletePhoto failed: ${res.statusCode} ${res.body}');
    }

    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
