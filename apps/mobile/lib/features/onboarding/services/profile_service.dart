import 'dart:convert';
import '../../../core/network/api_error.dart';
import '../../../core/location/location_result.dart';
import '../../../core/network/api_client.dart';
import '../models/update_profile_request.dart';
import '../models/gender.dart';
import '../models/availability.dart';
import '../models/intention.dart';
import '../models/profile.dart';
import '../../discovery/models/discover_profile.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';

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
      throw apiError(res, fallback: 'No se ha podido completar la operación');
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
      throw apiError(res, fallback: 'No se ha podido completar la operación');
    }
  }

  /// Deportes que juega el usuario (`Profile.sports`) — editable desde
  /// Settings en cualquier momento, no solo en el onboarding. Distinto de
  /// `Preferences.sportsWanted` (qué deportes busca en otros), que se
  /// edita en la hoja de preferencias de Discovery.
  Future<void> updateSports(List<Sport> sports) async {
    final res = await api.patch(
      '/me/profile',
      body: {'sports': sports.map((s) => s.apiValue).toList()},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido completar la operación');
    }
  }

  /// Género del propio perfil. A diferencia del resto de PATCH parciales
  /// de aquí, manda la clave SIEMPRE (incluso como null): el backend
  /// distingue "omitido" de "null explícito" para que se pueda volver a
  /// "prefiero no decirlo" tras haber elegido algo (`double_option` en
  /// `me/dto.rs`). Por eso no usa el idiom `'clave': ?valor`, que borraría
  /// la clave justo en el caso que hay que poder expresar.
  Future<void> updateGender(Gender? gender) async {
    final res = await api.patch(
      '/me/profile',
      body: {'gender': gender?.apiValue},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido guardar');
    }
  }

  /// Cuándo puede jugar. Mandar la lista la reemplaza entera, y una lista
  /// vacía borra la disponibilidad — mismo comportamiento que `sports`.
  Future<void> updateAvailability(WeeklyAvailability value) async {
    final res = await api.patch(
      '/me/profile',
      body: {'availability': value.mask},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(
        res,
        fallback: 'No se ha podido guardar tu disponibilidad',
      );
    }
  }

  /// A qué viene la persona. Manda la clave siempre, por la misma razón
  /// que `updateGender`: hay que poder volver a no decirlo.
  Future<void> updateIntention(Intention? intention) async {
    final res = await api.patch(
      '/me/profile',
      body: {'intention': intention?.apiValue},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido guardar');
    }
  }

  /// La descripción libre del perfil. Antes no se podía editar en ningún
  /// sitio: se rellenaba sola con la frase del "objetivo" del onboarding.
  Future<void> updateBio(String bio) async {
    final res = await api.patch('/me/profile', body: {'bio': bio}, auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido guardar la descripción');
    }
  }

  /// Señales de confianza estructuradas (`Profile.yearsPlaying/club/
  /// achievements`) — ver status.md, "Reposicionamiento de producto".
  /// Cualquier parámetro en `null` deja el valor existente sin tocar
  /// (mismo upsert parcial que el resto de `PATCH /me/profile`); pasar
  /// una lista vacía sí borra los logros existentes, a propósito, para
  /// poder vaciarla desde Settings.
  Future<void> updateExperience({
    int? yearsPlaying,
    String? club,
    double? avgPaceMinPerKm,
    double? avgDistanceKm,
    List<String>? achievements,
  }) async {
    final res = await api.patch(
      '/me/profile',
      body: {
        'yearsPlaying': ?yearsPlaying,
        'club': ?club,
        'avgPaceMinPerKm': ?avgPaceMinPerKm,
        'avgDistanceKm': ?avgDistanceKm,
        'achievements': ?achievements,
      },
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido completar la operación');
    }
  }

  /// Nivel auto-declarado por deporte — vive en su propia tabla en el
  /// backend (no en `Profile`), así que va por `PATCH /me/skill-levels`
  /// en vez de `updateProfile`/`updateExperience`. Upsert por deporte:
  /// un deporte no incluido en `levels` no se toca.
  Future<Map<Sport, SkillLevel>> updateSkillLevels(
    Map<Sport, SkillLevel> levels,
  ) async {
    final res = await api.patch(
      '/me/skill-levels',
      body: {'levels': skillLevelsToJson(levels)},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido guardar tu nivel');
    }

    return skillLevelsFromJson(jsonDecode(res.body));
  }

  /// Solo el radio de descubrimiento (`distanceKm`) — el resto de filtros
  /// (edad, deportes, género) van por `updatePreferences`, y se editan
  /// desde la hoja de preferencias de Discovery.
  Future<void> updateDiscoveryRadius(int distanceKm) async {
    final res = await api.patch(
      '/me/preferences',
      body: {'distanceKm': distanceKm},
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(
        res,
        fallback: 'No se han podido guardar tus preferencias',
      );
    }
  }

  /// Preferencias de a quién mostrar en Discovery (edad, deportes que
  /// quiere ver, género) — independiente del radio (ver
  /// `updateDiscoveryRadius` arriba). Los parámetros en `null` no se tocan,
  /// salvo `genderPreference`, que se manda siempre (por eso es `required`
  /// aunque sea nullable): null ahí es la opción real "cualquiera", no
  /// "déjalo como estaba" — misma razón que en `updateGender`.
  Future<void> updatePreferences({
    int? ageMin,
    int? ageMax,
    List<Sport>? sportsWanted,
    required Gender? genderPreference,
  }) async {
    final res = await api.patch(
      '/me/preferences',
      body: {
        'ageMin': ?ageMin,
        'ageMax': ?ageMax,
        'sportsWanted': ?sportsWanted?.map((s) => s.apiValue).toList(),
        'genderPreference': genderPreference?.apiValue,
      },
      auth: true,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(
        res,
        fallback: 'No se han podido guardar tus preferencias',
      );
    }
  }

  Future<MeResponse> getMe() async {
    final res = await api.get('/me', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido cargar tu perfil');
    }

    return MeResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<DiscoverProfile> getUserProfile(String userId) async {
    final res = await api.get('/users/$userId/profile', auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido completar la operación');
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
      throw apiError(res, fallback: 'No se ha podido completar la operación');
    }
  }

  /// Borra la cuenta entera, sin vuelta atrás. La confirmación (escribir
  /// "BORRAR") la pide la interfaz; aquí ya viene decidido.
  Future<void> deleteAccount() async {
    final res = await api.delete('/me', auth: true);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido borrar la cuenta');
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
      throw apiError(res, fallback: 'No se ha podido completar la operación');
    }

    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Profile> deletePhoto(String url) async {
    final res = await api.delete('/me/photos', body: {'url': url}, auth: true);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw apiError(res, fallback: 'No se ha podido borrar la foto');
    }

    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
