import 'strings.dart';

/// El castellano, que es el idioma en el que se escribió la app. Ésta es la
/// referencia: cualquier texto nuevo se escribe aquí primero y luego se
/// traduce.
class StringsEs extends Strings {
  const StringsEs();

  @override
  String get cancel => 'Cancelar';
  @override
  String get save => 'Guardar';
  @override
  String get retry => 'Reintentar';
  @override
  String get back => 'Volver';
  @override
  String get skip => 'Saltar';
  @override
  String get yes => 'Sí';
  @override
  String get no => 'No';
  @override
  String get close => 'Cerrar';
  @override
  String get delete => 'Borrar';
  @override
  String get next => 'Siguiente';
  @override
  String get somethingWentWrong => 'Algo ha ido mal';

  @override
  String get getStarted => 'Empezar';
  @override
  String get signIn => 'Entrar';
  @override
  String get createAccount => 'Crear cuenta';
  @override
  String get welcomeBack => 'Bienvenido de nuevo';
  @override
  String get createYourAccount => 'Crea tu cuenta';
  @override
  String get email => 'Email';
  @override
  String get password => 'Contraseña';
  @override
  String get repeatPassword => 'Repite la contraseña';
  @override
  String get newPassword => 'Contraseña nueva';
  @override
  String get forgotPassword => '¿Has olvidado tu contraseña?';
  @override
  String get noAccountRegister => '¿No tienes cuenta? Regístrate';
  @override
  String get haveAccountSignIn => '¿Ya tienes cuenta? Entra';
  @override
  String get passwordChangedSignIn =>
      'Contraseña cambiada. Entra con la nueva';
  @override
  String get couldNotCheckEmail => 'No se ha podido comprobar el email.';
  @override
  String get showPassword => 'Mostrar contraseña';
  @override
  String get hidePassword => 'Ocultar contraseña';
  @override
  String get minEightChars => 'Mínimo 8 caracteres';

  @override
  String get recoverPassword => 'Recuperar contraseña';
  @override
  String get whatIsYourEmail => '¿Cuál es tu email?';
  @override
  String get weSendYouACode =>
      'Te enviamos un código para elegir una contraseña nueva.';
  @override
  String get writeTheCode => 'Escribe el código';
  @override
  String get codeSixDigitsFifteenMin =>
      'Te hemos escrito con un código de 6 dígitos. Caduca en 15 minutos.';
  @override
  String get sendCode => 'Enviar código';
  @override
  String get changePassword => 'Cambiar contraseña';
  @override
  String get useAnotherEmail => 'Usar otro email';
  @override
  String get ifAccountExistsCodeSent =>
      'Si esa cuenta existe, le hemos enviado un código';
  @override
  String get writeYourEmail => 'Escribe tu email';
  @override
  String get codeIsSixDigits => 'El código tiene 6 dígitos';
  @override
  String get passwordNeedsEightChars =>
      'La contraseña necesita al menos 8 caracteres';
  @override
  String get changingClosesSessions =>
      'Al cambiarla se cierra la sesión en todos tus dispositivos.';

  @override
  String get verifyYourEmail => 'Verifica tu email';
  @override
  String get verify => 'Verificar';
  @override
  String get resendCode => 'Reenviar código';
  @override
  String resendCodeIn(int seconds) => 'Reenviar código ($seconds s)';
  @override
  String get codeSent => 'Te hemos enviado un código';
  @override
  String get codeResent => 'Código reenviado';
  @override
  String weWroteTo(String email) =>
      'Te hemos escrito a $email. El código caduca en 15 minutos.';

  @override
  String get tabDiscover => 'Descubrir';
  @override
  String get tabPartners => 'Compañeros';
  @override
  String get tabMatches => 'Partidos';
  @override
  String get tabProfile => 'Perfil';

  @override
  String get levelBeginner => 'Principiante';
  @override
  String get levelIntermediate => 'Intermedio';
  @override
  String get levelAdvanced => 'Avanzado';
  @override
  String get levelCompetitive => 'Competitivo';

  @override
  String get sportTennis => 'Tenis';
  @override
  String get sportRunning => 'Correr';
  @override
  String get tennisMatch => 'Partido de tenis';
  @override
  String get runningSession => 'Salida a correr';
  @override
  String get matchNoun => 'partido';
  @override
  String get runNoun => 'salida';

  @override
  String get genderMale => 'Hombre';
  @override
  String get genderFemale => 'Mujer';
  @override
  String get genderOther => 'Otro';
  @override
  String get genderMalePlural => 'Hombres';
  @override
  String get genderFemalePlural => 'Mujeres';
  @override
  String get genderOtherPlural => 'Otros';

  @override
  String get intentionCompete => 'Competir';
  @override
  String get intentionTrain => 'Entrenar';
  @override
  String get intentionLearn => 'Mejorar mi nivel';
  @override
  String get intentionFun => 'Divertirme';
  @override
  String get intentionCompeteDetail => 'Partidos serios, con marcador';
  @override
  String get intentionTrainDetail => 'Coger ritmo y mantenerme en forma';
  @override
  String get intentionLearnDetail =>
      'Busco a alguien mejor que me haga subir de nivel';
  @override
  String get intentionFunDetail => 'Sin presión, por el gusto de jugar';

  @override
  List<String> get weekdayNames => const [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];
  @override
  List<String> get weekdayShort =>
      const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  @override
  List<String> get bandNames => const ['Mañana', 'Tarde', 'Noche'];
  @override
  List<String> get monthNames => const [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  @override
  String get notSet => 'Sin definir';

  @override
  String get today => 'Hoy';
  @override
  String get tomorrow => 'Mañana';
  @override
  String inDays(int days) => 'En $days días';
  @override
  String longDate(String weekday, int day, String month) =>
      '$weekday $day de $month';
  @override
  String dateAtTime(String date, String time) => '$date a las $time';

  @override
  String get thisPerson => 'esta persona';
  @override
  String get noName => 'Sin nombre';
  @override
  String get unmatch => 'Dejar de ser compañeros';
  @override
  String unmatchConfirm(String name) =>
      '¿Seguro que quieres dejar de ser compañeros con $name? Se borrará '
      'también la conversación, y no se puede deshacer.';
  @override
  String get unmatchConfirmNoName =>
      '¿Seguro que quieres dejar de ser compañeros? Se borrará también la '
      'conversación, y no se puede deshacer.';
  @override
  String get yourPartners => 'Tus compañeros';
  @override
  String get searchByName => 'Buscar por nombre...';
  @override
  String get noPartnersYet => 'Todavía no tienes compañeros';
  @override
  String get noPartnersHint =>
      'Cuando alguien a quien has dado "Quiero jugar" te lo devuelva, '
      'aparecerá aquí y podréis hablar.';
  @override
  String noResultsFor(String query) => 'Sin resultados para "$query"';
  @override
  String get awaitingYourAnswer => 'Esperan tu respuesta';
  @override
  String get withAPlan => 'Con quedada';
  @override
  String get noPlansYet => 'Sin planes todavía';
  @override
  String sectionCount(String title, int count) => '$title · $count';
  @override
  String get proposeAMatch => 'Proponer un partido';
  @override
  String get proposeARun => 'Proponer salir a correr';
  @override
  String get seeCourtsNearby => 'Ver pistas cerca';
  @override
  String get reportSent => 'Reporte enviado';
  @override
  String get couldNotSendReport => 'No se ha podido enviar el reporte.';
  @override
  String get couldNotSendMessage => 'No se ha podido enviar el mensaje.';
  @override
  String get couldNotLoadMessages => 'No se han podido cargar los mensajes';
  @override
  String get noMessagesYet => 'Todavía no hay mensajes';
  @override
  String get playedOnce => 'Habéis jugado una vez';
  @override
  String playedNTimes(int times) => 'Habéis jugado $times veces';
  @override
  String get notPlayedYet => 'Aún no habéis quedado';
  @override
  String proposesYou(String when) => 'Te propone $when';
  @override
  String awaitingTheirAnswer(String when) => 'Esperando su respuesta · $when';

  @override
  String get waitingForAnswer => 'Esperando respuesta';
  @override
  String get youProposedAMatch => 'Has propuesto un partido';
  @override
  String get awaitsYourAnswer => 'Espera tu respuesta';
  @override
  String get theyProposeAMatch => 'Te propone un partido';
  @override
  String get matchConfirmed => 'Partido confirmado';
  @override
  String confirmedMatches(int count) =>
      count == 1 ? 'Partido confirmado' : 'Partidos confirmados';
  @override
  String get itDidNotSuitThem => 'No les venía bien';
  @override
  String get proposalDeclined => 'Propuesta rechazada';
  @override
  String get proposalCancelled => 'Propuesta cancelada';
  @override
  String get theyWithdrewTheProposal => 'Retiraron la propuesta';
  @override
  String get noSpecificPlace => 'Sin sitio concreto';

  @override
  String get couldNotCompleteOperation =>
      'No se ha podido completar la operación.';

  @override
  String get yourMatches => 'Tus partidos';
  @override
  String get nothingScheduled => 'Todavía no tienes nada agendado';
  @override
  String get nothingScheduledHint =>
      'Cuando propongas jugar a alguno de tus compañeros (o te lo propongan '
      'a ti), lo verás aquí.';
  @override
  String get waitingForYourAnswer => 'Esperando respuesta';
  @override
  String finishedCount(int count) => 'Terminados ($count)';
  @override
  String howDidItGoCount(int count) => '¿Qué tal fue? ($count)';
  @override
  String get tellingItMakesLevelsMean =>
      'Contarlo es lo que hace que los niveles del resto signifiquen algo.';
  @override
  String get didYouPlay => '¿Habéis jugado?';
  @override
  String get yesWePlayed => 'Sí, jugamos';
  @override
  String get itCouldNotBe => 'No pudo ser';
  @override
  String get howDidItEnd => '¿Quién ganó?';
  @override
  String get meWon => 'Yo';
  @override
  String get itWasNotPlayed => 'No se jugó';
  @override
  String get unanswered => 'Sin contestar';
  @override
  String sessionWith(String noun, String name) => 'Tu $noun con $name';
  @override
  String daysAgo(int days) => 'Hace $days días';
  @override
  String get yesterday => 'Ayer';
  @override
  String wouldYouSayPlaysAt(String name, String level) =>
      '¿Es $name $level?';
  @override
  String get whichWouldYouSay => '¿Cuál dirías que es?';

  @override
  String get meetUp => 'Quedada';
  @override
  String get couldNotOpenChat => 'No se pudo abrir el chat';
  @override
  String cancelTheSession(String noun) => '¿Cancelar el $noun?';
  @override
  String get withdrawTheProposal => '¿Retirar la propuesta?';
  @override
  String cancelNoun(String noun) => 'Cancelar $noun';
  @override
  String get withdraw => 'Retirar';
  @override
  String willBeNotified(String name) =>
      'Se le avisará a $name. Podéis volver a proponer otro día cuando '
      'queráis.';
  @override
  String proposalWillDisappearFor(String name) =>
      'La propuesta desaparecerá para $name.';
  @override
  String get sessionCancelled => 'Partido cancelado';
  @override
  String get proposalWithdrawn => 'Propuesta retirada';
  @override
  String get where => 'Dónde';
  @override
  String get whoYouPlayWith => 'Con quién juegas';
  @override
  String get openChat => 'Abrir chat';
  @override
  String get sessionConfirmed => 'Partido confirmado';
  @override
  String get notConfirmed => 'Sin confirmar';
  @override
  String waitingFor(String name) => 'Esperando a $name';
  @override
  String get waitingYourAnswerShort => 'Esperando tu respuesta';
  @override
  String get noLongerPlayed => 'Ya no se juega';
  @override
  String get itWasCancelled => 'Se canceló';
  @override
  String get alreadyStarted => 'Ya ha empezado';
  @override
  String get inLessThanAnHour => 'En menos de una hora';
  @override
  String inHours(int hours) => 'Dentro de $hours h';
  @override
  String inDaysShort(int days) => 'Dentro de $days días';
  @override
  String get missingWhereToPlay => 'Falta decidir dónde jugáis';
  @override
  String get missingCourtBooking => 'Falta reservar la pista';
  @override
  String get agreeWhereAndBook =>
      'Habéis quedado en el día y la hora, pero no en el sitio. Acordadlo en '
      'el chat y reservad la pista.';
  @override
  String get appDoesNotBookCourts =>
      'MatchPoint aún no reserva pistas. Habéis cerrado la quedada entre '
      'vosotros pero aún debéis contactar el club para alquilar la pista.';
  @override
  String get seeClubOnMaps => 'Ver el club en Maps';
  @override
  String get couldNotOpenMap => 'No se ha podido abrir el mapa';
  @override
  String yearsPlaying(int years) => '$years años jugando';
  @override
  String averageKm(String km) => '$km km de media';

  @override
  String get accept => 'Aceptar';
  @override
  String get decline => 'Rechazar';
  @override
  String get withdrawProposal => 'Retirar propuesta';

  @override
  String get statusConfirmed => 'Confirmado';
  @override
  String get statusDeclined => 'Rechazado';
  @override
  String get statusCancelled => 'Cancelado';

  @override
  String get noExperienceYet =>
      'Todavía no ha rellenado su experiencia.';

  @override
  String get settings => 'Ajustes';
  @override
  String get signOut => 'Cerrar sesión';
  @override
  String get signOutConfirm => '¿Seguro que quieres cerrar sesión?';
  @override
  String get deleteMyAccount => 'Borrar mi cuenta';
  @override
  String get cannotBeUndone => 'No se puede deshacer';
  @override
  String get account => 'Cuenta';
  @override
  String get profile => 'Perfil';
  @override
  String get location => 'Ubicación';
  @override
  String get searchRadius => 'Radio de búsqueda';
  @override
  String get searchRadiusHint =>
      'Hasta dónde buscamos gente, desde tu ubicación.';
  @override
  String get sports => 'Deportes';
  @override
  String get sportsHint =>
      'A qué juegas. Determina a quién ves en Descubrir y quién te ve a ti.';
  @override
  String get availability => 'Disponibilidad';
  @override
  String get whatDoYouCome => 'A qué vienes';
  @override
  String get whatTheyComeFor => 'A qué viene';
  @override
  String get description => 'Descripción';
  @override
  String get notWritten => 'Sin escribir';
  @override
  String get level => 'Nivel';
  @override
  String get experience => 'Experiencia';
  @override
  String get inviteSomeone => 'Invitar a alguien';
  @override
  String get preferNotToSay => 'Prefiero no decirlo';
  @override
  String get intentionShownHint =>
      'Aparece en tu perfil para que sepan qué buscas. Si no eliges nada, no '
      'se enseña.';
  @override
  String get aboutYou => 'Sobre ti';
  @override
  String get aboutMe => 'Sobre mi';
  @override
  String get mySports => 'Mis Deportes';
  @override
  String get seeMyPublicProfile => 'Ver mi perfil público';
  @override
  String get seeProfile => 'Ver perfil';
  @override
  String get changePhotos => 'Cambiar fotos';
  @override
  String get noProfile => 'Sin perfil';
  @override
  String get couldNotLoadProfile => 'No se pudo cargar el perfil';
  @override
  String get nothingWrittenYet => 'Todavía no has escrito nada.';
  @override
  String get noSportsChosen => 'Todavía no ha elegido deportes.';
  @override
  String get chooseSportsFirst => 'Elige tus deportes primero';
  @override
  String get partners => 'Compañeros';
  @override
  String get matchesStat => 'Partidos';
  @override
  String get matchStat => 'Partido';
  @override
  String get wonStat => 'Ganados';
  @override
  String get verified => 'Verificado';
  @override
  String get unverifiedTapToConfirm => 'Sin verificar — toca para confirmarlo';
  @override
  String get yearsPlayingTennis => 'Años jugando al tenis';
  @override
  String get club => 'Club';
  @override
  String get averagePaceLabel => 'Ritmo medio (min:seg / km)';
  @override
  String get averagePaceHint => 'Ej. 4:30';
  @override
  String get averageDistanceLabel => 'Distancia media (km)';
  @override
  String get averageDistanceHint => 'Ej. 10';
  @override
  String get tournamentsAchievements => 'Torneos / logros';
  @override
  String get achievementHint => 'Ej. Campeón provincial 2024';
  @override
  String get couldNotSaveLocation => 'No se ha podido guardar tu ubicación.';
  @override
  String get couldNotSaveRadius =>
      'No se ha podido guardar el radio de búsqueda.';
  @override
  String get couldNotSaveSports => 'No se han podido guardar tus deportes.';
  @override
  String get couldNotSaveChanges => 'No se han podido guardar los cambios.';
  @override
  String get couldNotSaveDescription =>
      'No se ha podido guardar tu descripción.';
  @override
  String get couldNotSaveLevel => 'No se ha podido guardar tu nivel.';
  @override
  String get couldNotSaveExperience =>
      'No se ha podido guardar tu experiencia.';
  @override
  String maxCharsPerAchievement(int max) =>
      'Máximo $max caracteres por logro';
  @override
  String maxAchievements(int max) => 'Máximo $max logros';
  @override
  String clubMaxLength(int max) =>
      'El club no puede superar los $max caracteres';
  @override
  String maxCharsUsed(int max, int used) =>
      'Máximo $max caracteres (llevas $used).';
  @override
  String averageKmLabel(String km) => '$km km medios';
  @override
  String pacePerKm(String pace) => '$pace min/km';
  @override
  String achievementsCount(int count) => '$count logro(s)';
  @override
  String sportAndLevel(String sport, String level) => '$sport: $level';
  @override
  String kmValue(int km) => '$km km';

  @override
  String get report => 'Reportar';

  @override
  String get whereDoYouPlay => '¿Dónde juegas?';
  @override
  String get postcodeHint =>
      'Escribe tu código postal y te mostraremos gente cerca de ti.';
  @override
  String get postcode => 'Código postal';
  @override
  String get postcodeExample => '29639';
  @override
  String get postcodeNotFound =>
      'No encontramos ese código postal. Revísalo o busca tu ciudad por el '
      'nombre.';
  @override
  String get couldNotSearchPostcode =>
      'No se ha podido buscar el código postal.';
  @override
  String get dontKnowSearchByCity => 'No lo sé — buscar por ciudad';
  @override
  String upToKm(int km) => 'Hasta $km km de distancia';
  @override
  String get onlyYourAreaIsUsed =>
      'Sólo usamos tu zona para calcular distancias. Nadie ve dónde vives: en '
      'los perfiles sólo aparece a cuántos kilómetros estás.';
  @override
  String get whichOfThese => '¿Cuál de estos?';
  @override
  String get lookingWhoPlaysAround => 'Mirando quién juega por ahí…';
  @override
  String get nobodyHereYet => 'Todavía no hay nadie por aquí';
  @override
  String get nobodyHereYetHint =>
      'Serías de los primeros. Te avisamos en cuanto alguien se apunte cerca '
      '— y mientras tanto puedes ampliar el radio para ver más lejos.';
  @override
  String get onePersonPlayingHere => 'Hay 1 persona jugando por aquí';
  @override
  String peoplePlayingHere(int count) => 'Hay $count personas jugando por aquí';
  @override
  String get youWillSeeThemAfterProfile =>
      'Podrás verlas en cuanto termines de crear tu perfil.';

  @override
  String get yourMatchStep => 'Tu partido';
  @override
  String get helpUsFindYourRival => 'Ayúdanos a encontrar tu rival perfecto.';
  @override
  String get whatIsYourLevel => '¿Cuál es tu nivel?';
  @override
  String get whenCanYouUsuallyPlay => '¿Cuándo sueles poder jugar?';
  @override
  String get weUseItToShowWhoMatches =>
      'Lo usamos para enseñarte antes quién coincide contigo.';

  @override
  String get yourProfileStep => 'Tu perfil';
  @override
  String get displayName => 'Nombre visible';
  @override
  String get birthDate => 'Fecha de nacimiento';
  @override
  String get chooseDate => 'Elegir fecha';
  @override
  String get gender => 'Género';
  @override
  String get aboutYouHint =>
      'Menciona lo que creas que otros jugadores de tenis deberían saber de ti.';
  @override
  String get bioExample =>
      'Juego los martes por la tarde cerca del centro. Busco a alguien '
      'constante más que competitivo.';

  @override
  String get chooseYourAvatar => 'Tu foto';
  @override
  String get avatarHint =>
      'Sube o haz una foto en la que se te vea a ti, o jugando al tenis.';

  @override
  String get chooseWhereYouPlayFirst =>
      'Elige dónde juegas para poder enseñarte gente cerca de ti';
  @override
  String get writeYourDisplayName =>
      'Escribe el nombre con el que quieres aparecer';
  @override
  String displayNameTooLong(int max) =>
      'El nombre no puede superar los $max caracteres';
  @override
  String get chooseYourBirthDate => 'Elige tu fecha de nacimiento';
  @override
  String get couldNotCompleteSignUp =>
      'No se ha podido completar el registro.';
  @override
  String get leaveSignUp => '¿Salir del registro?';
  @override
  String get leaveSignUpHint =>
      'Vas a volver a la pantalla de inicio de sesión. Nada de lo que '
      'completaste todavía se guardó — no se pierde ningún dato ya creado, '
      'pero tendrás que volver a empezar el registro.';
  @override
  String get createMyProfile => 'Crear mi perfil';
  @override
  String get leave => 'Salir';

  @override
  String get sessionExpired => 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
  @override
  String get noLongerAvailable => 'Esto ya no está disponible.';
  @override
  String get tooManyRequests =>
      'Has hecho demasiadas peticiones seguidas. Espera un momento.';
  @override
  String get serverFailure =>
      'No hemos podido completar la operación. Inténtalo de nuevo en unos '
      'segundos.';
  @override
  String get noConnection =>
      'Sin conexión. Comprueba tu red e inténtalo de nuevo.';
  @override
  String get serverTooSlow =>
      'El servidor está tardando demasiado. Inténtalo de nuevo.';

  @override
  String get deleteYourAccount => 'Borrar tu cuenta';
  @override
  String get deleteCannotBeUndone =>
      'Esto no se puede deshacer. Se borra para siempre:';
  @override
  String get partnersAndConversations =>
      'Tus compañeros y todas tus conversaciones';
  @override
  String get peopleWillStopSeeingYou =>
      'La gente con la que hablabas dejará de verte, y no hay forma de '
      'recuperar nada de esto más tarde.';
  @override
  String typeToConfirm(String word) => 'Escribe $word para confirmar:';
  @override
  String get deleteAccount => 'Borrar cuenta';

  @override
  String get postcodeOrCity => 'Código postal o ciudad';
  @override
  String get postcodeOrCityHint =>
      'Escribe tu código postal (29630) o el nombre de tu ciudad.';
  @override
  String get noResultsTryExactName =>
      'Sin resultados. Prueba con el nombre exacto del sitio o con tu código '
      'postal.';

  @override
  String get thisIsHowTheyLook => 'Así se verán';
  @override
  String get thisIsHowItLooks => 'Así se verá';
  @override
  String get landscapeCropExplainerMany =>
      'MatchPoint usa fotos horizontales, así que las recortamos por el '
      'centro. Quita las que no te convenzan.';
  @override
  String get landscapeCropExplainerOne =>
      'MatchPoint usa fotos horizontales, así que la recortamos por el '
      'centro. Si te corta algo importante, elige otra.';
  @override
  String get discardAll => 'Descartar todas';
  @override
  String get chooseAnother => 'Elegir otra';
  @override
  String useTheseCount(int count) => 'Usar estas ($count)';
  @override
  String get useThisOne => 'Usar esta';
  @override
  String maxPhotos(int max) => 'Máximo $max fotos.';
  @override
  String get addPhoto => 'Añadir foto';
  @override
  String get takeAPhoto => 'Hacer una foto';
  @override
  String get chooseFromGallery => 'Elegir de la galería';
  @override
  String youCanChooseUpTo(int limit) => 'Puedes elegir hasta $limit';
  @override
  String get useAnAvatar => 'Usar un avatar';
  @override
  String get avatarGalleryHint =>
      'Ilustraciones de la app, si prefieres no poner tu cara';

  @override
  String youOverlapCount(int count) => 'Coincidís ($count)';
  @override
  String get onlyTheOtherPersonCan => 'Sólo puede la otra persona';
  @override
  String onlyPersonCan(String name) => 'Sólo puede $name';

  @override
  String get startWithWhenYouCanPlay => 'Empieza por cuándo puedes jugar';
  @override
  String get discoveryIntroBody =>
      'Marca las franjas en las que sueles tener libre y te ponemos primero a '
      'quien coincide contigo. Toca a alguien para ver su perfil, o dale a '
      '"Quiero jugar" y, si te lo devuelve, ya podéis quedar.';
  @override
  String get youAreNowPartners => '¡Ahora sois compañeros!';
  @override
  String get keepLooking => 'Seguir buscando';
  @override
  String get sendMessage => 'Enviar mensaje';
  @override
  String get organizeMatch => 'Organizar partido';
  @override
  String get couldNotOpenChatTryMatches =>
      'No se pudo abrir el chat, prueba desde Compañeros';
  @override
  String get chooseAtLeastOneSport =>
      'Elige al menos un deporte para poder ver perfiles';
  @override
  String get filtersDecideWhoWeShow =>
      'Deciden a quién te mostramos. El radio de distancia se cambia en '
      'Ajustes, junto a tu ubicación.';
  @override
  String get whenICanPlay => 'Cuándo puedo jugar';
  @override
  String get anyTime => 'Cualquier momento';
  @override
  String get ageRange => 'Rango de edad';
  @override
  String ageRangeValue(int from, int to) => '$from - $to años';
  @override
  String get sportsYouWantToSee => 'Deportes que quieres ver';
  @override
  String get notNow => 'Ahora no';
  @override
  String playWith(String name) => 'Jugar con $name';
  @override
  String get iWantToPlay => 'Quiero jugar';
  @override
  String get noSharedSlots => 'No coincidís en ninguna franja horaria';
  @override
  String get oneSharedSlot => 'Coincidís en 1 franja horaria';
  @override
  String sharedSlots(int count) => 'Coincidís en $count franjas horarias';
  @override
  String get thisWeekend => 'Este finde';
  @override
  String get weekdayEvenings => 'Entre semana, tardes';
  @override
  String get weekdayMornings => 'Entre semana, mañanas';
  @override
  String get whenCanYouPlay => '¿Cuándo puedes jugar?';
  @override
  String get whenFilterHint =>
      'Te enseñamos primero a quien le venga bien lo mismo que a ti. Marca '
      'las franjas en las que sueles tener libre.';
  @override
  String get clearFilter => 'Quitar filtro';
  @override
  String seeWhoCan(int count) => 'Ver quién puede ($count)';

  @override
  String get proposalSent => 'Propuesta enviada';
  @override
  String get meetingPoint => 'Punto de encuentro';
  @override
  String get whereDoYouPlayQ => '¿Dónde jugáis?';
  @override
  String get meetingPointQ => '¿Punto de encuentro?';
  @override
  String get markExactSpot =>
      'Marca el sitio exacto en el mapa — mucho más útil que decir sólo el '
      'municipio.';
  @override
  String get chooseClubOrMark =>
      'Elige un club de los que hay cerca, o marca el punto exacto en el mapa.';
  @override
  String get chooseNearbyClub => 'Elegir un club cerca';
  @override
  String get markOnTheMap => 'Marcar en el mapa';
  @override
  String get setLocationInSettings =>
      'Pon tu ubicación en Ajustes para poder elegir sitio en el mapa.';
  @override
  String get searchPlaceByName => 'Buscar un sitio por nombre';
  @override
  String get whereYouPlay => 'Dónde jugáis';
  @override
  String get filterByName => 'Filtrar por nombre...';
  @override
  String get mapServiceBusy =>
      'El servicio de mapas está saturado ahora mismo. Prueba otra vez en '
      'unos segundos.';
  @override
  String get noPlaceWithThatName => 'Ningún sitio con ese nombre';
  @override
  String get tryAnotherPartOfName => 'Prueba con otra parte del nombre.';
  @override
  String get osmDataMayBeMissing =>
      'Los datos vienen de OpenStreetMap, así que puede faltar alguna pista. '
      'Puedes ampliar la búsqueda o marcar el punto en el mapa.';
  @override
  String searchUpToKm(int km) => 'Buscar hasta $km km';
  @override
  String get noNameInOsmYouConfirm =>
      'Sin nombre en OpenStreetMap · lo confirmas tú';
  @override
  String get tennisCourts => 'Pistas de tenis';
  @override
  String courtsCount(int count) => '$count pistas';
  @override
  String get whatIsThisPlaceCalled => '¿Cómo se llama este sitio?';
  @override
  String osmHasCourtsNoName(String courts) =>
      'OpenStreetMap tiene aquí $courts, pero sin nombre. Ponle uno para que '
      'la otra persona sepa dónde es — la ubicación exacta ya va incluida.';
  @override
  String get placeName => 'Nombre del sitio';
  @override
  String get useThisPlace => 'Usar este sitio';
  @override
  String get atWhatTime => '¿A qué hora?';
  @override
  String get hoursTheyCanUsually => 'Horas a las que suele poder';
  @override
  String personUsuallyCanAtTheseHours(String name) =>
      '$name suele poder a estas horas';
  @override
  String proposeAt(String time) => 'Proponer a las $time';
  @override
  String get whatDay => '¿Qué día?';
  @override
  String get daysTheyUsuallyHaveFree => 'Días que suele tener libres';
  @override
  String personUsuallyFreeTheseDays(String name) =>
      '$name suele tener libres estos días';

  @override
  String get couldNotLoadYourProfile =>
      'No se pudo cargar tu perfil. Inténtalo otra vez.';
  @override
  String get emailAlreadyInUse => 'Ese email ya está en uso';
  @override
  String get emailLooksInvalid => 'Ese email no parece válido';
  @override
  String get passwordAtLeastEight =>
      'La contraseña debe tener al menos 8 caracteres';
  @override
  String get passwordAtMost72 =>
      'La contraseña no puede superar los 72 caracteres';
  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';
  @override
  String get couldNotSignIn => 'No se ha podido iniciar sesión';
  @override
  String get couldNotSendCode => 'No se ha podido enviar el código';
  @override
  String get couldNotChangePassword => 'No se ha podido cambiar la contraseña';
  @override
  String get later => 'Más tarde';
  @override
  String get inviteMessage =>
      '¿Jugamos? Estoy usando MatchPoint, una app para encontrar con quién '
      'jugar al tenis cerca de casa y a las horas que te vienen bien.';

  @override
  String get yourProfileAndPhotos => 'Tu perfil y tus fotos';
  @override
  String get agreedSessions =>
      'Los partidos y salidas que tengas acordados';
  @override
  String get yourLevelExperiencePreferences =>
      'Tu nivel, tu experiencia y tus preferencias';

  @override
  String get welcomeTagline =>
      'Encuentra con quién jugar al tenis: gente de tu nivel, cerca de ti, y '
      'disponibles cuando tú lo estés.';
  @override
  String get whenDoYouMeet => '¿Cuándo quedáis?';
  @override
  String get chooseAnotherDay => 'Elegir otro día';
  @override
  String get couldNotLoadPartners => 'No se han podido cargar tus compañeros.';
  @override
  String get noPartnersAtAll => 'Todavía no tienes ningún compañero';
  @override
  String get whoDoYouProposeItTo => '¿A quién se lo propones?';
  @override
  String get proposeMatchHere => 'Proponer partido aquí';
  @override
  String get shareClubAndTimeHint =>
      'el club y el horario a tu compañero, y ya lo confirmáis vosotros.';
  @override
  String get couldNotRegisterDecision =>
      'No se ha podido registrar tu decisión';
  @override
  String get couldNotOpenConversation =>
      'No se ha podido abrir la conversación';
  @override
  String get conversationNoLongerAvailable =>
      'Esta conversación ya no está disponible';
  @override
  String get couldNotMarkAsRead => 'No se han podido marcar como leídos';
  @override
  String get couldNotSaveDescriptionShort =>
      'No se ha podido guardar la descripción';
  @override
  String get tryMoreFreeSlots =>
      'Prueba con más franjas libres, o quita los filtros para ver a todo el '
      'mundo que hay cerca.';
  @override
  String get widenTheRadius =>
      'Amplía el radio de búsqueda para ver gente de más lejos. Te avisamos '
      'cuando se apunte alguien nuevo por tu zona.';
  @override
  String get addAnythingUseful =>
      'Añade cualquier información que pueda interesarle a tu futuro '
      'compañero.';
  @override
  String get couldNotReadYourLocation => 'No hemos podido leer tu ubicación.';
  @override
  String get noLocationInProfile =>
      'Todavía no tienes ubicación en tu perfil.';
  @override
  String tennisCourtsAt(String place) => 'Pistas de tenis · $place';

  @override
  String get placeNotFound => 'Sitio no encontrado';
  @override
  String get couldNotSearchPlaces => 'No se han podido buscar sitios.';

  @override
  String mapIsAtFallback(String place) =>
      'No hemos podido leer tu ubicación. Esto es $place, no tu zona.';
  @override
  String noLocationSearchAbove(String place) =>
      'Todavía no tienes ubicación en tu perfil. Esto es $place: busca tu '
      'zona arriba.';
  @override
  String get weDoNotCheckAvailability =>
      'No comprobamos si hay pista libre a esa hora — le propones el club y '
      'el horario a tu compañero, y ya lo confirmáis vosotros.';

  @override
  String get findYourMatch => 'Busca tu partido';

  @override
  String get anyLevel => 'Cualquiera';
  @override
  String get levelSheetHint =>
      'Un partido igualado es mejor partido. Es el nivel que cada uno dice '
      'tener, no un ranking.';
  @override
  String get atNights => 'Por las noches';
  @override
  String get seeEveryone => 'Ver a todo el mundo';

  @override
  String get reportUser => 'Reportar usuario';
  @override
  String get chooseAnAvatar => 'Elige un avatar';
  @override
  String get couldNotUploadAllPhotos => 'No se han podido subir todas las fotos.';
  @override
  String get profileNeedsOnePhoto => 'Tu perfil necesita al menos una foto.';
  @override
  String get couldNotDeletePhoto => 'No se ha podido borrar la foto';
  @override
  String get yourPhotos => 'Tus fotos';
  @override
  String get photos => 'Fotos';
  @override
  String get writeAMessage => 'Escribe un mensaje...';
  @override
  String get couldNotSaveFilters => 'No se han podido guardar los filtros.';
  @override
  String get filters => 'Filtros';
  @override
  String get change => 'Cambiar';
  @override
  String get referenceOptional => 'Referencia (opcional)';
  @override
  String get referenceHint => 'Ej: entrada del parque, junto a la fuente';
  @override
  String get useThisSpot => 'Usar este punto';
  @override
  String get proposeWithoutPlace => 'Proponer sin sitio';
  @override
  String get couldNotLoadList => 'No se pudo cargar el listado';
  @override
  String get couldNotCreateAccount => 'No se ha podido crear la cuenta';
  @override
  String get couldNotVerifyEmail => 'No se ha podido verificar el email';
  @override
  String get tennisClubsNearby => 'Clubes de tenis cerca';
  @override
  String get searchCityOrArea => 'Buscar ciudad o zona...';
  @override
  String get clearFilters => 'Quitar filtros';
  @override
  String get widenRadius => 'Ampliar el radio';
  @override
  String get inviteSomeoneYouPlayWith => 'Invitar a alguien con quien juegas';
  @override
  String get couldNotLoadProfiles => 'No se han podido cargar los perfiles';
  @override
  String get couldNotUnmatch => 'No se ha podido deshacer el match';
  @override
  String get couldNotSendProposal => 'No se ha podido enviar la propuesta';
  @override
  String get couldNotAnswerProposal => 'No se ha podido responder a la propuesta';
  @override
  String get couldNotLoadSessions => 'No se han podido cargar tus quedadas';
  @override
  String get couldNotLoadHistory => 'No se ha podido cargar el historial';
  @override
  String get couldNotSaveAnswer => 'No se ha podido guardar tu respuesta';
  @override
  String get couldNotSave => 'No se ha podido guardar';
  @override
  String get couldNotSaveAvailability => 'No se ha podido guardar tu disponibilidad';
  @override
  String get couldNotSavePreferences => 'No se han podido guardar tus preferencias';
  @override
  String get couldNotDeleteAccountMsg => 'No se ha podido borrar la cuenta';

  @override
  String get reasonInappropriate => 'Comportamiento inapropiado';
  @override
  String get reasonFakeProfile => 'Perfil falso';
  @override
  String get reasonSpam => 'Spam o publicidad';
  @override
  String get reasonOffensive => 'Contenido ofensivo';
  @override
  String get reasonOther => 'Otro';
  @override
  String get youWon => 'Ganaste';
  @override
  String get youLost => 'Perdiste';
  @override
  String get itWasADraw => 'Empate';

  @override
  String get confirm => 'Confirmar';

  @override
  List<String> get weekdayInitials =>
      const ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  String get noClubsAround =>
      'No hay clubes registrados por esta zona. Prueba a buscar otra ciudad.';

  @override
  String get openInMaps => 'Abrir en Maps';

  @override
  String levelAccurateMine(int n) => n == 1
      ? '1 persona confirma tu nivel'
      : '$n personas confirman tu nivel';
  @override
  String levelAccurateTheirs(int n) => n == 1
      ? '1 persona confirma su nivel'
      : '$n personas confirman su nivel';
  @override
  String levelHigherMine(int n) => n == 1
      ? '1 persona cree que juegas mejor de lo que pones'
      : '$n personas creen que juegas mejor de lo que pones';
  @override
  String levelHigherTheirs(int n) => n == 1
      ? '1 persona cree que juega mejor de lo que pone'
      : '$n personas creen que juega mejor de lo que pone';
  @override
  String levelLowerMine(int n) => n == 1
      ? '1 persona cree que te sobra nivel en tu perfil'
      : '$n personas creen que te sobra nivel en tu perfil';
  @override
  String levelLowerTheirs(int n) => n == 1
      ? '1 persona cree que le sobra nivel en su perfil'
      : '$n personas creen que le sobra nivel en su perfil';

  @override
  String weekRangeSameMonth(int fromDay, int toDay, String month) =>
      '$fromDay-$toDay de $month';
  @override
  String weekRangeAcrossMonths(
    int fromDay,
    String fromMonth,
    int toDay,
    String toMonth,
  ) => '$fromDay $fromMonth - $toDay $toMonth';

  @override
  String get noPermissionForThis => 'No tienes permiso para hacer esto.';
  @override
  String get canSwapAvatarLater => 'Puedes cambiarlo por una foto tuya cuando quieras, desde tu perfil.';
  @override
  String get onePhoto => 'Una foto';
  @override
  String get lessThanOneKm => 'menos de 1 km';
  @override
  String get veryClose => 'Muy cerca';
  @override
  String get pickTheExactSpot => 'Elige el punto exacto';
  @override
  String get theseSlotsSuitBoth => 'Estos huecos os vienen bien a los dos.';
  @override
  String get nobodyNearbyYet => 'Por ahora no hay nadie cerca';
  @override
  String get tennisCourtsGeneric => 'Pistas de tenis';
  @override
  String get allOverpassServersFailed => 'Todos los servidores de Overpass fallaron';
  @override
  String get bioHint => 'Soy una persona entusiasmada por el tenis. Busco a alguien para jugar a menudo.';

  @override
  String theseSlotsSuitYouAnd(String name) =>
      'Estos huecos os vienen bien a ti y a $name.';
  @override
  String kmAway(String km) => 'A $km km';

  @override
  String get aboutSection => 'Acerca de MatchPoint';
  @override
  String get privacyPolicy => 'Política de privacidad';
  @override
  String get termsOfUse => 'Términos de uso';
  @override
  String get writeToUs => 'Escríbenos';
  @override
  String get writeToUsHint => 'La app acaba de nacer. ¿Qué mejorarías o qué le falta?';
  @override
  String get feedbackSubject => 'MatchPoint — sugerencia';
  @override
  String get couldNotOpenLink => 'No se ha podido abrir el enlace';
  @override
  String noEmailAppFound(String email) => 'No hay ninguna app de correo configurada. Escríbenos a $email';
  @override
  String get copy => 'Copiar';

  @override
  String get orPickAnAvatar => 'O elige uno de estos dibujos y cámbialo cuando quieras desde tu perfil.';
}
