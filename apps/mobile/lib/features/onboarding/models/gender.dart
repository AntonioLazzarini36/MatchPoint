import 'package:match_point/core/i18n/app_locale.dart';
/// Género del propio usuario (`Profile.gender`) y, por separado, lo que
/// quiere ver en Discovery (`Preferences.genderPreference`).
///
/// Declararlo es opcional en ambos casos: `null` significa "prefiero no
/// decirlo" en el perfil y "cualquiera" en las preferencias. El backend
/// distingue "campo omitido" de "campo mandado como null" precisamente
/// para que se pueda volver a esa opción tras haber elegido otra (ver
/// `double_option` en `services/api-rust/src/me/dto.rs`).
enum Gender { male, female, other }

extension GenderApi on Gender {
  String get apiValue {
    switch (this) {
      case Gender.male:
        return 'MALE';
      case Gender.female:
        return 'FEMALE';
      case Gender.other:
        return 'OTHER';
    }
  }

  /// Cómo se nombra a la persona en su propio perfil.
  String get label {
    switch (this) {
      case Gender.male:
        return S.current.genderMale;
      case Gender.female:
        return S.current.genderFemale;
      case Gender.other:
        return S.current.genderOther;
    }
  }

  /// Cómo se nombra al grupo al elegirlo como preferencia — "Hombres"
  /// lee mucho mejor que "Hombre" en "quiero ver: ...".
  String get pluralLabel {
    switch (this) {
      case Gender.male:
        return S.current.genderMalePlural;
      case Gender.female:
        return S.current.genderFemalePlural;
      case Gender.other:
        return S.current.genderOtherPlural;
    }
  }

  static Gender? fromApi(Object? v) {
    switch (v?.toString()) {
      case 'MALE':
        return Gender.male;
      case 'FEMALE':
        return Gender.female;
      case 'OTHER':
        return Gender.other;
      default:
        return null;
    }
  }
}
