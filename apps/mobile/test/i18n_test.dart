import 'package:flutter_test/flutter_test.dart';
import 'package:match_point/core/i18n/app_locale.dart';
import 'package:match_point/core/i18n/strings_en.dart';
import 'package:match_point/core/i18n/strings_es.dart';

/// Lo que estas pruebas protegen no es la calidad de la traducción — eso lo
/// mira una persona — sino que **no se quede nada a medias**, que es como se
/// rompe una app bilingüe: alguien añade un texto, lo escribe en castellano, y
/// nadie se entera hasta que un usuario inglés se encuentra una frase suelta
/// en español.
///
/// La primera línea de defensa ni siquiera está aquí: `Strings` es una clase
/// abstracta, así que un texto sin traducir **no compila**. Esto cubre lo que
/// el compilador no puede ver.
void main() {
  const es = StringsEs();
  const en = StringsEn();

  test('el inglés no se deja frases en castellano', () {
    // Palabras que no existen en inglés y delatan una traducción olvidada.
    // Se buscan con espacios/límites para no cazar subcadenas por accidente.
    const marcas = [
      'ñ', '¿', '¡', 'á', 'é', 'í', 'ó', 'ú',
    ];
    final sospechosos = <String>[];
    for (final texto in _todos(en)) {
      for (final m in marcas) {
        if (texto.contains(m)) {
          sospechosos.add(texto);
          break;
        }
      }
    }
    expect(
      sospechosos,
      isEmpty,
      reason: 'estos textos ingleses llevan caracteres del castellano',
    );
  });

  test('ningún texto se queda vacío en ninguno de los dos idiomas', () {
    // Un getter que devuelve '' compila igual de bien que uno traducido, y en
    // pantalla es un hueco que nadie sabe explicar.
    expect(_todos(es).where((t) => t.trim().isEmpty), isEmpty);
    expect(_todos(en).where((t) => t.trim().isEmpty), isEmpty);
  });

  test('el castellano y el inglés dicen cosas distintas', () {
    // Si una cadena es idéntica en los dos idiomas suele ser que se copió sin
    // traducir. Se permiten las que de verdad coinciden (nombres propios,
    // unidades), listadas a mano para que añadir una sea una decisión.
    const iguales = {
      'Email', 'MatchPoint', 'Club', 'Tenis', 'Tennis', 'Sep', '29639',
    };
    final identicas = <String>[];
    final e = _todos(es).toList();
    final i = _todos(en).toList();
    for (var k = 0; k < e.length && k < i.length; k++) {
      if (e[k] == i[k] && !iguales.contains(e[k]) && e[k].length > 3) {
        identicas.add(e[k]);
      }
    }
    expect(
      identicas,
      isEmpty,
      reason: 'idénticas en los dos idiomas: ¿sin traducir?',
    );
  });

  test('cambiar de idioma cambia lo que devuelve S', () {
    LocaleController.locale.value = AppLocale.es;
    expect(S.current.signIn, 'Entrar');
    LocaleController.locale.value = AppLocale.en;
    expect(S.current.signIn, 'Sign in');
  });

  test('cada idioma se llama a sí mismo en su propio idioma', () {
    // Quien busca su idioma en la lista busca la palabra que reconoce. Si la
    // app está en un idioma que no habla, traducir los nombres le deja sin
    // salida.
    expect(AppLocale.es.label, 'Español');
    expect(AppLocale.en.label, 'English');
  });
}

/// Todos los textos sin parámetros de una implementación.
///
/// Se listan a mano y no por reflexión porque `dart:mirrors` no existe en
/// Flutter. Con la clase abstracta de por medio, olvidarse de añadir uno aquí
/// sólo debilita la prueba; no deja pasar un texto sin traducir, que es lo que
/// impide el compilador.
Iterable<String> _todos(dynamic s) => [
  s.cancel, s.save, s.retry, s.back, s.skip, s.yes, s.no, s.close, s.delete,
  s.next, s.somethingWentWrong, s.getStarted, s.signIn, s.createAccount,
  s.welcomeBack, s.createYourAccount, s.password, s.repeatPassword,
  s.newPassword, s.forgotPassword, s.noAccountRegister, s.haveAccountSignIn,
  s.passwordChangedSignIn, s.couldNotCheckEmail, s.showPassword,
  s.hidePassword, s.minEightChars, s.recoverPassword,
  s.whatIsYourEmail, s.weSendYouACode, s.writeTheCode,
  s.codeSixDigitsFifteenMin, s.sendCode, s.changePassword, s.useAnotherEmail,
  s.ifAccountExistsCodeSent, s.writeYourEmail, s.codeIsSixDigits,
  s.passwordNeedsEightChars, s.changingClosesSessions, s.verifyYourEmail,
  s.verify, s.resendCode, s.codeSent, s.codeResent, s.tabDiscover,
  s.tabPartners, s.tabMatches, s.tabProfile, s.levelBeginner,
  s.levelIntermediate, s.levelAdvanced, s.levelCompetitive, s.tennisMatch,
  s.runningSession, s.genderMale, s.genderFemale, s.genderOther,
  s.intentionCompete, s.intentionTrain, s.intentionLearn, s.intentionFun,
  s.intentionCompeteDetail, s.intentionTrainDetail, s.intentionLearnDetail,
  s.intentionFunDetail, s.notSet, s.today, s.tomorrow, s.yourPartners,
  s.searchByName, s.noPartnersYet, s.noPartnersHint, s.awaitingYourAnswer,
  s.withAPlan, s.noPlansYet, s.proposeAMatch, s.seeCourtsNearby, s.reportSent,
  s.noMessagesYet, s.playedOnce, s.notPlayedYet, s.waitingForAnswer,
  s.matchConfirmed, s.proposalDeclined, s.proposalCancelled, s.noSpecificPlace,
  s.yourMatches, s.nothingScheduled, s.nothingScheduledHint, s.didYouPlay,
  s.yesWePlayed, s.itCouldNotBe, s.howDidItEnd, s.meWon,
  s.itWasNotPlayed, s.unanswered, s.whichWouldYouSay, s.meetUp, s.where,
  s.whoYouPlayWith, s.openChat, s.sessionConfirmed, s.notConfirmed,
  s.missingCourtBooking, s.seeClubOnMaps, s.settings, s.signOut,
  s.signOutConfirm, s.deleteMyAccount, s.cannotBeUndone, s.account, s.profile,
  s.location, s.searchRadius, s.sports, s.availability, s.whatDoYouCome,
  s.description, s.notWritten, s.level, s.experience, s.inviteSomeone,
  s.preferNotToSay, s.aboutYou, s.aboutMe, s.mySports, s.seeMyPublicProfile,
  s.changePhotos, s.noProfile, s.couldNotLoadProfile, s.whereDoYouPlay,
  s.postcode, s.dontKnowSearchByCity, s.whichOfThese, s.nobodyHereYet,
  s.yourMatchStep, s.whatIsYourLevel, s.whenCanYouUsuallyPlay,
  s.yourProfileStep, s.displayName, s.birthDate, s.chooseDate, s.gender,
  s.chooseYourAvatar, s.createMyProfile, s.leave, s.sessionExpired,
  s.noConnection, s.serverTooSlow, s.deleteYourAccount, s.deleteAccount,
  s.postcodeOrCity, s.thisIsHowTheyLook, s.discardAll, s.chooseAnother,
  s.useThisOne, s.addPhoto, s.takeAPhoto, s.chooseFromGallery, s.useAnAvatar,
  s.youAreNowPartners, s.keepLooking, s.organizeMatch, s.whenICanPlay,
  s.anyTime, s.ageRange, s.notNow, s.iWantToPlay, s.thisWeekend,
  s.whenCanYouPlay, s.clearFilter, s.proposalSent, s.meetingPoint,
  s.chooseNearbyClub, s.markOnTheMap, s.whereYouPlay, s.tennisCourts,
  s.placeName, s.useThisPlace, s.atWhatTime, s.whatDay, s.later,
  s.welcomeTagline, s.whenDoYouMeet, s.chooseAnotherDay, s.proposeMatchHere,
  s.placeNotFound,
].cast<String>();
