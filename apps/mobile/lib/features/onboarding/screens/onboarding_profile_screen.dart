import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_result.dart';
import '../../../core/network/api.dart';
import '../../../core/storage/token_storage.dart';
import '../../auth/models/auth_response.dart';
import '../../auth/models/login_request.dart';
import '../../auth/models/register_request.dart';
import '../../auth/services/auth_service.dart';
import '../models/update_profile_request.dart';
import '../onboarding_controller.dart';
import '../services/profile_service.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/utils/app_sports.dart';
import '../../discovery/models/skill_level.dart';
import '../../discovery/models/sport.dart';

import 'package:match_point/core/ui/widgets/onboarding/onboarding_step_scaffold.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_profile_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_play_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_location_step.dart';
import 'package:match_point/core/ui/widgets/onboarding/onboarding_avatar_step.dart';
import 'package:match_point/features/onboarding/models/gender.dart';
import 'package:match_point/features/onboarding/models/availability.dart';
import 'package:match_point/features/auth/screens/email_verification_screen.dart';
import 'dart:typed_data';

import 'package:match_point/core/ui/profile/avatar_gallery.dart';
import 'package:match_point/core/ui/profile/photo_source_sheet.dart';
import 'package:match_point/core/ui/profile/photo_crop_preview.dart';
import '../../../core/network/connection_error.dart';
import 'package:match_point/core/i18n/app_locale.dart';

class OnboardingProfileScreen extends StatefulWidget {
  /// Null cuando se llega aquí ya logueado (cuenta a medias de un intento
  /// interrumpido, ver el redirect de `router.dart`) — en ese caso el
  /// paso final solo termina de rellenar el perfil, no vuelve a registrar.
  final String? email;
  final String? password;

  const OnboardingProfileScreen({super.key, this.email, this.password});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  // El wizard pasó de seis pantallas a cuatro, y en otro orden:
  //
  //   0. Ubicación   — primero, porque es lo que decide si hay alguien
  //   1. Perfil      — nombre, edad, género, descripción
  //   2. Tu partido  — nivel + cuándo sueles poder (lo que empareja)
  //   3. Avatar      — opcional; quien lo salta se lleva uno por defecto
  //
  // Lo que desapareció: elegir deporte (la app es de tenis, ver
  // `app_sports.dart`), las experiencia (años/club/logros — se rellenan
  // desde Ajustes cuando ya hay motivo) y el paso entero de preferencias
  // (rango de edad, género, "a qué vienes"), que son filtros con valores
  // por defecto razonables y que en una app vacía sólo sirven para dejarla
  // más vacía. Todo eso sigue existiendo en Ajustes.
  //
  // Y desapareció también **"Así te van a ver"**, que era el paso final.
  // Enseñaba una tarjeta con lo que acababas de escribir y pedía
  // confirmarla. El problema no era que sobrara información, es que llegaba
  // en el peor momento: una pantalla más entre "ya he terminado" y estar
  // dentro, que no pide nada y no se puede editar desde ahí — para cambiar
  // algo hay que ir hacia atrás igualmente. Y lo que enseñaba (nombre, edad,
  // ciudad, avatar) ya se acaba de escribir en las dos pantallas anteriores.
  // El perfil sigue siendo visible y editable entero desde Perfil, que es
  // donde se mira cuando de verdad hay ganas de retocarlo.
  /// Nombre de cada paso para la analitica. Por nombre y no por numero: si
  /// manana se reordenan los pasos, un embudo guardado por indices pasa a
  /// mentir sin que nadie se entere.
  static const _stepNames = ['ubicacion', 'perfil', 'nivel_horario', 'avatar'];

  static const _totalPages = 4;
  static const _locationStepIndex = 0;
  static const _profileStepIndex = 1;
  static const _playStepIndex = 2;
  static const _avatarStepIndex = 3;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  WeeklyAvailability _availability = WeeklyAvailability.empty;
  double _radiusKm = 25;
  LocationResult? _selectedLocation;

  Gender? _gender;

  Map<Sport, SkillLevel> _skillLevels = {};

  final displayNameCtrl = TextEditingController();
  final bioCtrl = TextEditingController();
  DateTime? birthDate;

  /// El avatar elegido en el último paso. No se convierte a bytes hasta el
  /// final: guardar la ruta del asset deja el paso instantáneo (cambiar de
  /// avatar es repintar una rejilla, no recortar y recodificar un PNG) y el
  /// trabajo se hace una sola vez, al crear el perfil de verdad.
  String? _avatarAsset;

  /// La foto propia, ya recortada a 16:9 y lista para subir.
  ///
  /// Excluyente con [_avatarAsset]: al crear la cuenta se sube **una**
  /// imagen, asi que elegir una cosa borra la otra en vez de dejar las dos
  /// marcadas y tener que inventar cual gana.
  Uint8List? _photoBytes;

  /// Con qué se queda quien salta el paso.
  ///
  /// Saltar **no puede** significar quedarse sin foto: `/discover` esconde los
  /// perfiles que no tienen ninguna, así que sería registrarse para no
  /// aparecer, sin que nada lo avise. Se coge el primero de la lista y no uno
  /// al azar para que el registro siga siendo reproducible.
  static String get _fallbackAvatar => kAvatarAssets.first;

  late final OnboardingController controller;
  late final AuthService authService;

  @override
  void initState() {
    super.initState();
    controller = OnboardingController(ProfileService(Api.client));
    authService = AuthService(Api.client);
    Analytics.onboardingStart();
    _skipIfHasProfile();
  }

  Future<void> _skipIfHasProfile() async {
    final has = await controller.hasProfile();
    if (has && mounted) context.go(AppRoutes.shell);
  }

  @override
  void dispose() {
    _pageController.dispose();
    displayNameCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  /// Ya no se elige: es el deporte de la app (ver `app_sports.dart`). Se
  /// sigue mandando la lista porque `Profile.sports` sigue siendo un array
  /// en el backend, y volver a encender un segundo deporte no debería
  /// obligar a migrar los perfiles creados mientras tanto.
  List<String> _sportsForBackend() =>
      enabledSports.map((s) => s.apiValue).toList();

  /// El paso de "Tu juego" es opcional: se puede pasar sin decir el nivel ni
  /// marcar horario. En vez de escribir "(opcional)" en la pantalla, el
  /// botón mismo dice "Saltar" mientras no haya nada puesto (feedback del
  /// usuario, 2026-08-02).
  bool get _isPlayStepEmpty =>
      _skillLevels.isEmpty && _availability.isEmpty;

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = birthDate ?? DateTime(now.year - 25, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year - 16, now.month, now.day),
    );

    if (picked != null) setState(() => birthDate = picked);
  }

  /// Cámara o galería para la foto propia, en el paso de la foto.
  ///
  /// Pasa por el mismo recorte y la misma vista previa que el resto de la app
  /// (`showPhotoCropPreview`), y no por un camino corto: es lo que garantiza
  /// que lo que se sube aquí esté en 16:9 como todo lo demás, y que quien la
  /// elige vea el encuadre **antes** de que se suba.
  ///
  /// `limit: 1` porque al crear la cuenta sólo se sube una imagen. Las demás
  /// se añaden luego desde el perfil, donde ya hay motivo para hacerlo.
  Future<void> _pickOwnPhoto() async {
    final pick = await pickPhotos(context, limit: 1);
    if (!mounted || pick.isEmpty) return;

    // La hoja también ofrece los avatares. Si sale por ahí no hay nada que
    // recortar: es uno de los dibujos que ya están en la rejilla de abajo, y
    // se marca como si se hubiera tocado allí.
    final asset = pick.avatarAsset;
    if (asset != null) {
      setState(() {
        _avatarAsset = asset;
        _photoBytes = null;
      });
      return;
    }

    final originals = <Uint8List>[];
    for (final file in pick.files) {
      originals.add(await file.readAsBytes());
    }
    if (!mounted) return;

    final cropped = await showPhotoCropPreview(context, originals: originals);
    if (!mounted || cropped == null || cropped.isEmpty) return;

    setState(() {
      _photoBytes = cropped.first;
      _avatarAsset = null;
    });
  }

  static const _maxDisplayNameLength = 30;

  Future<void> _goNextOrFinish() async {
    if (_currentPage == _locationStepIndex && _selectedLocation == null) {
      controller.setError(
        S.current.chooseWhereYouPlayFirst,
      );
      return;
    }

    if (_currentPage == _profileStepIndex) {
      final name = displayNameCtrl.text.trim();
      if (name.isEmpty) {
        controller.setError(S.current.writeYourDisplayName);
        return;
      }
      if (name.length > _maxDisplayNameLength) {
        controller.setError(
          S.current.displayNameTooLong(_maxDisplayNameLength),
        );
        return;
      }
      if (birthDate == null) {
        controller.setError(S.current.chooseYourBirthDate);
        return;
      }
    }

    if (_currentPage < _avatarStepIndex) {
      controller.setError(null);
      Analytics.onboardingStep(_stepNames[_currentPage]);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Último paso: nada existe en el backend hasta aquí, así que este botón
    // es el que crea la cuenta entera.
    await _completeRegistration();
  }

  /// Nada existe en el backend hasta este punto: aquí se crea (o se
  /// recupera, si un intento anterior falló a medias) el usuario, se
  /// guarda el perfil, y se suben todas las fotos elegidas — uno detrás
  /// de otro, disparado por el único "Comenzar" final del wizard.
  Future<void> _completeRegistration() async {
    controller.setError(null);
    controller.setLoading(true);

    try {
      final email = widget.email;
      final password = widget.password;

      if (email != null && password != null) {
        AuthResponse tokens;
        try {
          tokens = await authService.register(
            RegisterRequest(email: email, password: password),
          );
        } catch (_) {
          // Recuperación: si un intento anterior ya llegó a crear el
          // usuario (p.ej. se cortó la conexión justo después del
          // register) o hay una carrera rara con el check de
          // disponibilidad, intentar login con las mismas credenciales
          // es la forma segura de continuar en vez de quedar atascado.
          tokens = await authService.login(
            LoginRequest(email: email, password: password),
          );
        }
        await TokenStorage.saveToken(tokens.accessToken);
        await TokenStorage.saveRefreshToken(tokens.refreshToken);
      }

      final req = UpdateProfileRequest(
        displayName: displayNameCtrl.text.trim(),
        birthDate: _formatDate(birthDate!),
        city: _selectedLocation?.displayName,
        bio: bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
        sports: _sportsForBackend(), // ✅ solo Tenis/Correr
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );
      await controller.service.updateProfile(req);
      // Aparte de `updateProfile` porque el género tiene que poder
      // mandarse como null explícito ("prefiero no decirlo") y
      // `UpdateProfileRequest` omite los nulos — ver `updateGender`.
      await controller.service.updateGender(_gender);
      await controller.service.updateAvailability(_availability);
      await controller.service.updateDiscoveryRadius(_radiusKm.round());
      // El resto de preferencias (rango de edad, género que quiero ver) se
      // quedan en sus valores por defecto: ya no se preguntan en el
      // registro y se cambian desde Ajustes. `sportsWanted` sí se manda,
      // para que sea el deporte activo y no una lista vacía.
      await controller.service.updatePreferences(
        ageMin: 18,
        ageMax: 60,
        sportsWanted: enabledSports,
        genderPreference: null,
      );

      final levelsForMySports = Map<Sport, SkillLevel>.fromEntries(
        _skillLevels.entries.where((e) => enabledSports.contains(e.key)),
      );
      if (levelsForMySports.isNotEmpty) {
        await controller.service.updateSkillLevels(levelsForMySports);
      }

      // El registro ya no sube fotos de la galería: sube el avatar elegido, o
      // el de reserva si se saltó el paso, para que nadie acabe sin foto y
      // por tanto invisible en Descubrir. Se convierte a bytes aquí y no al
      // elegirlo: cambiar de avatar en la rejilla no debe costar un recorte.
      // La foto propia manda; si no hay, el avatar elegido; si tampoco, el
      // de reserva, para que nadie acabe sin foto y por tanto invisible en
      // Descubrir. Las dos salidas acaban en los mismos bytes PNG 16:9,
      // asi que la subida es la misma.
      final bytes =
          _photoBytes ??
          await loadAvatarBytes(_avatarAsset ?? _fallbackAvatar);
      await controller.service.uploadPhoto(
        bytes: bytes,
        filename: '${DateTime.now().microsecondsSinceEpoch}.png',
        contentType: 'image/png',
      );

      if (!mounted) return;

      // Verificar el email va justo aquí y no escondido en Ajustes: es el
      // único momento en que alguien tiene el correo a mano y entiende por
      // qué se lo pedimos. Es saltable a propósito — no verificar no
      // bloquea nada todavía, y plantar un muro nada más registrarse es la
      // forma más rápida de que alguien no llegue a probar la app.
      // Se pregunta al servidor si la verificación está activa antes de
      // enseñar la pantalla. Sin un dominio de correo propio, el proveedor
      // sólo entrega al titular de la cuenta, así que a cualquier otro le
      // saldría un fallo de envío justo al terminar de registrarse — la
      // peor primera impresión posible. Si la consulta falla, no se enseña:
      // ante la duda, mejor no meter a nadie en un callejón sin salida.
      var verificationEnabled = false;
      try {
        verificationEnabled =
            (await controller.service.getMe()).emailVerificationEnabled;
      } catch (_) {
        // se queda en false
      }
      if (!mounted) return;

      if (email != null && verificationEnabled) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
      }

      Analytics.onboardingStep(_stepNames[_avatarStepIndex]);
      Analytics.signupCompleted();

      if (mounted) context.go(AppRoutes.shell);
    } catch (e) {
      controller.setError(
        friendlyError(e, fallback: S.current.couldNotCompleteSignUp),
      );
    } finally {
      if (mounted) controller.setLoading(false);
    }
  }

  /// En la primera página, "atrás" ya no tiene otra página del wizard a
  /// la que volver — significa abandonar el registro/onboarding entero,
  /// así que confirma antes (pedido del usuario, 2026-08-03: es "cambiar
  /// a otra lógica", no un simple paso atrás). En el resto de páginas
  /// sigue siendo solo navegación normal dentro del wizard, sin preguntar
  /// nada.
  Future<void> _goBack() async {
    if (_currentPage > 0) {
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.current.leaveSignUp),
        content: Text(S.current.leaveSignUpHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Por si esta pantalla se alcanzó ya logueado (cuenta a medias de un
    // intento anterior, ver el comentario de `widget.email` arriba) —
    // sin esto, `router.dart` redirige de vuelta a /onboarding en vez de
    // dejar ver login/registro, porque sigue habiendo un token válido.
    Analytics.onboardingAbandoned(_stepNames[_currentPage]);
    await TokenStorage.clear();
    if (mounted) context.go(AppRoutes.onboardingAuth);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return OnboardingStepScaffold(
          currentPage: _currentPage,
          totalPages: _totalPages,
          onBack: _goBack,
          // Nada existe todavía hasta completar el wizard entero — no
          // hay a dónde "saltar" (el redirect global mandaría de vuelta
          // aquí igualmente).
          onSkip: null,
          // El paso del avatar ya no bloquea: quien lo salta se lleva uno
          // por defecto (ver `_fallbackAvatar`), que es mejor que quedarse
          // sin foto y por tanto fuera de Descubrir.
          onNext: controller.isLoading ? null : _goNextOrFinish,
          isLoading: controller.isLoading,
          // El paso del avatar es ahora el último, así que su botón crea la
          // cuenta — y lo dice, incluso cuando se salta sin elegir ninguno
          // (se lleva el de reserva, ver `_fallbackAvatar`): "Saltar" en el
          // botón que de verdad te registra sería mentir sobre lo que hace.
          nextLabel: _currentPage == _avatarStepIndex
              ? S.current.createMyProfile
              : (_currentPage == _playStepIndex && _isPlayStepEmpty
                    ? S.current.skip
                    : S.current.next),
          errorText: controller.error,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              OnboardingLocationStep(
                location: _selectedLocation,
                onLocationChanged: (loc) =>
                    setState(() => _selectedLocation = loc),
                radiusKm: _radiusKm,
                onRadiusChanged: (v) => setState(() => _radiusKm = v),
              ),
              OnboardingProfileStep(
                displayNameCtrl: displayNameCtrl,
                birthDate: birthDate,
                onPickBirthDate: _pickBirthDate,
                birthDateLabel: birthDate == null
                    ? S.current.chooseDate
                    : _formatDate(birthDate!),
                gender: _gender,
                onGenderChanged: (g) => setState(() => _gender = g),
                bioCtrl: bioCtrl,
                onNameSubmitted: _goNextOrFinish,
              ),
              OnboardingPlayStep(
                skillLevels: _skillLevels,
                onSkillLevelsChanged: (levels) =>
                    setState(() => _skillLevels = levels),
                availability: _availability,
                onAvailabilityChanged: (v) => setState(() => _availability = v),
              ),
              OnboardingAvatarStep(
                selectedAsset: _avatarAsset,
                onSelect: (asset) => setState(() {
                  _avatarAsset = asset;
                  _photoBytes = null;
                }),
                photoBytes: _photoBytes,
                onPickPhoto: _pickOwnPhoto,
                onClearPhoto: () => setState(() => _photoBytes = null),
              ),
            ],
          ),
        );
      },
    );
  }
}
