/// Todo el texto que ve el usuario, declarado una sola vez.
///
/// Es una clase **abstracta** y no un mapa de claves a propósito: así, añadir
/// un texto obliga a implementarlo en los dos idiomas o el proyecto no
/// compila. Con un `Map<String, String>` una clave sin traducir se descubre
/// en el móvil, en producción y en el idioma que no hablas.
///
/// Las traducciones son **literales**. No se aprovecha para reescribir ni
/// mejorar nada: si una frase en castellano se queda corta, se arregla en
/// castellano y luego se traduce igual. Mezclar las dos cosas hace imposible
/// saber si un texto cambió porque se tradujo o porque alguien lo reescribió.
///
/// Los que llevan parámetros son métodos, no getters — el orden de las
/// palabras cambia de un idioma a otro y no se pueden pegar trozos sueltos.
abstract class Strings {
  const Strings();

  // --- Genéricos, usados en toda la app ---
  String get cancel;
  String get save;
  String get retry;
  String get back;
  String get skip;
  String get yes;
  String get no;
  String get close;
  String get delete;
  String get next;
  String get somethingWentWrong;

  // --- Bienvenida y acceso ---
  String get getStarted;
  String get signIn;
  String get createAccount;
  String get welcomeBack;
  String get createYourAccount;
  String get email;
  String get password;
  String get repeatPassword;
  String get newPassword;
  String get forgotPassword;
  String get noAccountRegister;
  String get haveAccountSignIn;
  String get passwordChangedSignIn;
  String get couldNotCheckEmail;
  String get showPassword;
  String get hidePassword;
  String get minEightChars;

  // --- Recuperar contraseña ---
  String get recoverPassword;
  String get whatIsYourEmail;
  String get weSendYouACode;
  String get writeTheCode;
  String get codeSixDigitsFifteenMin;
  String get sendCode;
  String get changePassword;
  String get useAnotherEmail;
  String get ifAccountExistsCodeSent;
  String get writeYourEmail;
  String get codeIsSixDigits;
  String get passwordNeedsEightChars;
  String get changingClosesSessions;

  // --- Verificar email ---
  String get verifyYourEmail;
  String get verify;
  String get resendCode;
  String resendCodeIn(int seconds);
  String get codeSent;
  String get codeResent;
  String weWroteTo(String email);

  // --- Vocabulario base: pestañas, niveles, deportes, días ---
  String get tabDiscover;
  String get tabPartners;
  String get tabMatches;
  String get tabProfile;

  String get levelBeginner;
  String get levelIntermediate;
  String get levelAdvanced;
  String get levelCompetitive;

  String get sportTennis;
  String get sportRunning;
  String get tennisMatch;
  String get runningSession;
  String get matchNoun;
  String get runNoun;

  String get genderMale;
  String get genderFemale;
  String get genderOther;
  String get genderMalePlural;
  String get genderFemalePlural;
  String get genderOtherPlural;

  String get intentionCompete;
  String get intentionTrain;
  String get intentionLearn;
  String get intentionFun;
  String get intentionCompeteDetail;
  String get intentionTrainDetail;
  String get intentionLearnDetail;
  String get intentionFunDetail;

  List<String> get weekdayNames;
  List<String> get weekdayShort;
  List<String> get bandNames;
  List<String> get monthNames;
  String get notSet;

  // --- Fechas ---
  String get today;
  String get tomorrow;
  String inDays(int days);
  /// "lunes 12 de agosto" / "Monday 12 August"
  String longDate(String weekday, int day, String month);
  /// La fecha y la hora juntas: "… a las 18:30" / "… at 18:30".
  String dateAtTime(String date, String time);

  // --- Compañeros y chat ---
  String get thisPerson;
  String get noName;
  String get unmatch;
  String unmatchConfirm(String name);
  String get unmatchConfirmNoName;
  String get yourPartners;
  String get searchByName;
  String get noPartnersYet;
  String get noPartnersHint;
  String noResultsFor(String query);
  String get awaitingYourAnswer;
  String get withAPlan;
  String get noPlansYet;
  String sectionCount(String title, int count);
  String get proposeAMatch;
  String get proposeARun;
  String get seeCourtsNearby;
  String get reportSent;
  String get couldNotSendReport;
  String get couldNotSendMessage;
  String get couldNotLoadMessages;
  String get noMessagesYet;
  String get playedOnce;
  String playedNTimes(int times);
  String get notPlayedYet;
  String proposesYou(String when);
  String awaitingTheirAnswer(String when);

  // --- Estado de una propuesta ---
  String get waitingForAnswer;
  String get youProposedAMatch;
  String get awaitsYourAnswer;
  String get theyProposeAMatch;
  String get matchConfirmed;

  /// Cabecera de la lista de partidos ya confirmados, que lleva el contador
  /// al lado.
  ///
  /// Existe aparte de [matchConfirmed] porque aquél titula **una** propuesta
  /// ("Partido confirmado") y ahí el singular es correcto. Reutilizarlo para
  /// la cabecera daba "Partido confirmado · 2".
  ///
  /// Las otras dos cabeceras de esa pantalla no necesitan esto: "Esperan tu
  /// respuesta" y "Esperando respuesta" son oraciones, y valen para
  /// cualquier cantidad. Sólo hace falta cuando la cabecera es un sustantivo
  /// contable.
  String confirmedMatches(int count);
  String get itDidNotSuitThem;
  String get proposalDeclined;
  String get proposalCancelled;
  String get theyWithdrewTheProposal;
  String get noSpecificPlace;

  String get couldNotCompleteOperation;

  // --- Tus partidos ---
  String get yourMatches;
  String get nothingScheduled;
  String get nothingScheduledHint;
  String get waitingForYourAnswer;
  String finishedCount(int count);
  String howDidItGoCount(int count);
  String get tellingItMakesLevelsMean;
  String get didYouPlay;
  String get yesWePlayed;
  String get itCouldNotBe;
  String get howDidItEnd;
  /// Quién ganó: tú. La otra opción es el nombre del rival tal cual, así
  /// que no necesita cadena.
  String get meWon;
  String get itWasNotPlayed;
  String get unanswered;
  String sessionWith(String noun, String name);
  String daysAgo(int days);
  String get yesterday;
  String wouldYouSayPlaysAt(String name, String level);
  String get whichWouldYouSay;

  // --- Ficha de una quedada ---
  String get meetUp;
  String get couldNotOpenChat;
  String cancelTheSession(String noun);
  String get withdrawTheProposal;
  String cancelNoun(String noun);
  String get withdraw;
  String willBeNotified(String name);
  String proposalWillDisappearFor(String name);
  String get sessionCancelled;
  String get proposalWithdrawn;
  String get where;
  String get whoYouPlayWith;
  String get openChat;
  String get sessionConfirmed;
  String get notConfirmed;
  String waitingFor(String name);
  String get waitingYourAnswerShort;
  String get noLongerPlayed;
  String get itWasCancelled;
  String get alreadyStarted;
  String get inLessThanAnHour;
  String inHours(int hours);
  String inDaysShort(int days);
  String get missingWhereToPlay;
  String get missingCourtBooking;
  String get agreeWhereAndBook;
  String get appDoesNotBookCourts;
  String get seeClubOnMaps;
  String get couldNotOpenMap;
  String yearsPlaying(int years);
  String averageKm(String km);

  String get accept;
  String get decline;
  String get withdrawProposal;

  /// Etiquetas cortas del estado, en la chapa de la ficha.
  ///
  /// En masculino: la pantalla se titula "Quedada" pero lo que hay
  /// dentro es un **partido**, y la chapa se lee junto a eso. En
  /// castellano la concordancia se nota; en inglés no cambia nada.
  String get statusConfirmed;
  String get statusDeclined;
  String get statusCancelled;

  String get noExperienceYet;

  // --- Ajustes y perfil ---
  String get settings;
  String get signOut;
  String get signOutConfirm;
  String get deleteMyAccount;
  String get cannotBeUndone;
  String get account;
  String get profile;
  String get location;
  String get searchRadius;
  String get searchRadiusHint;
  String get sports;
  String get sportsHint;
  String get availability;
  String get whatDoYouCome;
  String get whatTheyComeFor;
  String get description;
  String get notWritten;
  String get level;
  String get experience;
  String get inviteSomeone;
  String get inviteSomeoneHint;
  String get preferNotToSay;
  String get intentionShownHint;
  String get aboutYou;
  String get aboutMe;
  String get mySports;
  String get seeMyPublicProfile;
  String get seeProfile;
  String get changePhotos;
  String get noProfile;
  String get couldNotLoadProfile;
  String get nothingWrittenYet;
  String get noSportsChosen;
  String get chooseSportsFirst;
  String get partners;
  String get matchesStat;
  String get matchStat;
  String get wonStat;
  String get verified;
  String get unverifiedTapToConfirm;
  String get yearsPlayingTennis;
  String get club;
  String get averagePaceLabel;
  String get averagePaceHint;
  String get averageDistanceLabel;
  String get averageDistanceHint;
  String get tournamentsAchievements;
  String get achievementHint;
  String get couldNotSaveLocation;
  String get couldNotSaveRadius;
  String get couldNotSaveSports;
  String get couldNotSaveChanges;
  String get couldNotSaveDescription;
  String get couldNotSaveLevel;
  String get couldNotSaveExperience;
  String maxCharsPerAchievement(int max);
  String maxAchievements(int max);
  String clubMaxLength(int max);
  String maxCharsUsed(int max, int used);
  String averageKmLabel(String km);
  String pacePerKm(String pace);
  String achievementsCount(int count);
  String sportAndLevel(String sport, String level);
  String kmValue(int km);

  String get report;

  // --- Registro guiado ---
  String get whereDoYouPlay;
  String get postcodeHint;
  String get postcode;
  String get postcodeExample;
  String get postcodeNotFound;
  String get couldNotSearchPostcode;
  String get dontKnowSearchByCity;
  String upToKm(int km);
  String get onlyYourAreaIsUsed;
  String get whichOfThese;
  String get lookingWhoPlaysAround;
  String get nobodyHereYet;
  String get nobodyHereYetHint;
  String get onePersonPlayingHere;
  String peoplePlayingHere(int count);
  String get youWillSeeThemAfterProfile;

  String get yourMatchStep;
  String get helpUsFindYourRival;
  String get whatIsYourLevel;
  String get whenCanYouUsuallyPlay;
  String get weUseItToShowWhoMatches;

  String get yourProfileStep;
  String get displayName;
  String get birthDate;
  String get chooseDate;
  String get gender;
  String get aboutYouHint;
  String get bioExample;

  String get chooseYourAvatar;
  String get avatarHint;

  String get chooseWhereYouPlayFirst;
  String get writeYourDisplayName;
  String displayNameTooLong(int max);
  String get chooseYourBirthDate;
  String get couldNotCompleteSignUp;
  String get leaveSignUp;
  String get leaveSignUpHint;
  String get createMyProfile;
  String get leave;

  // --- Errores de red y de la API ---
  String get sessionExpired;
  String get noLongerAvailable;
  String get tooManyRequests;
  String get serverFailure;
  String get noConnection;
  String get serverTooSlow;

  // --- Borrar cuenta ---
  String get deleteYourAccount;
  String get deleteCannotBeUndone;
  String get partnersAndConversations;
  String get peopleWillStopSeeingYou;
  String typeToConfirm(String word);
  String get deleteAccount;

  // --- Buscar ubicación ---
  String get postcodeOrCity;
  String get postcodeOrCityHint;
  String get noResultsTryExactName;

  // --- Fotos ---
  String get thisIsHowTheyLook;
  String get thisIsHowItLooks;
  String get landscapeCropExplainerMany;
  String get landscapeCropExplainerOne;
  String get discardAll;
  String get chooseAnother;
  String useTheseCount(int count);
  String get useThisOne;
  String maxPhotos(int max);
  String get addPhoto;
  String get takeAPhoto;
  String get chooseFromGallery;
  String youCanChooseUpTo(int limit);
  String get useAnAvatar;
  String get avatarGalleryHint;

  // --- Rejilla de disponibilidad ---
  String youOverlapCount(int count);
  String get onlyTheOtherPersonCan;
  String onlyPersonCan(String name);

  // --- Descubrir ---
  String get startWithWhenYouCanPlay;
  String get discoveryIntroBody;
  String get youAreNowPartners;
  String get keepLooking;
  String get sendMessage;
  String get organizeMatch;
  String get couldNotOpenChatTryMatches;
  String get chooseAtLeastOneSport;
  String get filtersDecideWhoWeShow;
  String get whenICanPlay;
  String get anyTime;
  String get ageRange;
  String ageRangeValue(int from, int to);
  String get sportsYouWantToSee;
  String get notNow;
  String playWith(String name);
  String get iWantToPlay;
  String get noSharedSlots;
  String get oneSharedSlot;
  String sharedSlots(int count);
  String get thisWeekend;
  String get weekdayEvenings;
  String get weekdayMornings;
  String get whenCanYouPlay;
  String get whenFilterHint;
  String get clearFilter;
  String seeWhoCan(int count);

  // --- Proponer una quedada ---
  String get proposalSent;
  String get meetingPoint;
  String get whereDoYouPlayQ;
  String get meetingPointQ;
  String get markExactSpot;
  String get chooseClubOrMark;
  String get chooseNearbyClub;
  String get markOnTheMap;
  String get setLocationInSettings;
  String get searchPlaceByName;
  String get whereYouPlay;
  String get filterByName;
  String get mapServiceBusy;
  String get noPlaceWithThatName;
  String get tryAnotherPartOfName;
  String get osmDataMayBeMissing;
  String searchUpToKm(int km);
  String get noNameInOsmYouConfirm;
  String get tennisCourts;
  String courtsCount(int count);
  String get whatIsThisPlaceCalled;
  String osmHasCourtsNoName(String courts);
  String get placeName;
  String get useThisPlace;
  String get atWhatTime;
  String get hoursTheyCanUsually;
  String personUsuallyCanAtTheseHours(String name);
  String proposeAt(String time);
  String get whatDay;
  String get daysTheyUsuallyHaveFree;
  String personUsuallyFreeTheseDays(String name);

  // --- Mensajes de error de acceso ---
  String get couldNotLoadYourProfile;
  String get emailAlreadyInUse;
  String get emailLooksInvalid;
  String get passwordAtLeastEight;
  String get passwordAtMost72;
  String get passwordsDoNotMatch;
  String get couldNotSignIn;
  String get couldNotSendCode;
  String get couldNotChangePassword;
  String get later;
  String get inviteMessage;

  String get yourProfileAndPhotos;
  String get agreedSessions;
  String get yourLevelExperiencePreferences;

  String get welcomeTagline;
  String get whenDoYouMeet;
  String get chooseAnotherDay;
  String get couldNotLoadPartners;
  String get noPartnersAtAll;
  String get whoDoYouProposeItTo;
  String get proposeMatchHere;
  String get shareClubAndTimeHint;
  String get couldNotRegisterDecision;
  String get couldNotOpenConversation;
  String get conversationNoLongerAvailable;
  String get couldNotMarkAsRead;
  String get couldNotSaveDescriptionShort;
  String get tryMoreFreeSlots;
  String get widenTheRadius;
  String get addAnythingUseful;
  String get couldNotReadYourLocation;
  String get noLocationInProfile;
  String tennisCourtsAt(String place);

  String get placeNotFound;
  String get couldNotSearchPlaces;

  String mapIsAtFallback(String place);
  String noLocationSearchAbove(String place);
  String get weDoNotCheckAvailability;

  String get findYourMatch;

  String get anyLevel;
  String get levelSheetHint;
  String get atNights;
  String get seeEveryone;

  String get reportUser;
  String get chooseAnAvatar;
  String get couldNotUploadAllPhotos;
  String get profileNeedsOnePhoto;
  String get couldNotDeletePhoto;
  String get yourPhotos;
  String get photos;
  String get writeAMessage;
  String get couldNotSaveFilters;
  String get filters;
  String get change;
  String get referenceOptional;
  String get referenceHint;
  String get useThisSpot;
  String get proposeWithoutPlace;
  String get couldNotLoadList;
  String get couldNotCreateAccount;
  String get couldNotVerifyEmail;
  String get tennisClubsNearby;
  String get searchCityOrArea;
  String get clearFilters;
  String get widenRadius;
  String get inviteSomeoneYouPlayWith;
  String get couldNotLoadProfiles;
  String get couldNotUnmatch;
  String get couldNotSendProposal;
  String get couldNotAnswerProposal;
  String get couldNotLoadSessions;
  String get couldNotLoadHistory;
  String get couldNotSaveAnswer;
  String get couldNotSave;
  String get couldNotSaveAvailability;
  String get couldNotSavePreferences;
  String get couldNotDeleteAccountMsg;

  String get reasonInappropriate;
  String get reasonFakeProfile;
  String get reasonSpam;
  String get reasonOffensive;
  String get reasonOther;
  String get youWon;
  String get youLost;
  String get itWasADraw;

  String get confirm;

  /// Las iniciales de la cabecera de la rejilla.
  ///
  /// En castellano caben en una letra porque la X de miércoles evita el
  /// choque con martes. En inglés no: Tuesday y Thursday empiezan igual, y
  /// Saturday y Sunday también, así que esos cuatro necesitan dos.
  List<String> get weekdayInitials;

  String get noClubsAround;

  String get openInMaps;

  // --- Lo que opina la gente de tu nivel ---
  //
  // Seis frases y no una con piezas sueltas: en ingles el verbo concuerda con
  // el numero ("1 person confirms" / "3 people confirm"), asi que pasar un
  // "3 personas" ya montado y pegarle el resto detras no funciona. Cada
  // idioma monta su frase entera.

  /// "3 personas confirman tu nivel" — en tu propio perfil.
  String levelAccurateMine(int votes);

  /// "3 personas confirman su nivel" — en el perfil de otra persona.
  String levelAccurateTheirs(int votes);

  /// "3 personas creen que juegas mejor de lo que pones".
  String levelHigherMine(int votes);

  /// "3 personas creen que juega mejor de lo que pone".
  String levelHigherTheirs(int votes);

  /// "3 personas creen que te sobra nivel en tu perfil".
  String levelLowerMine(int votes);

  /// "3 personas creen que le sobra nivel en su perfil".
  String levelLowerTheirs(int votes);

  /// El rango de una semana en el selector de día: "1-7 de agosto".
  ///
  /// Dos métodos y no uno con un `if` dentro porque el castellano mete un
  /// "de" que el inglés no tiene, y sólo en la forma corta.
  String weekRangeSameMonth(int fromDay, int toDay, String month);

  /// Cuando la semana cruza de mes: "31 agosto - 6 septiembre".
  String weekRangeAcrossMonths(
    int fromDay,
    String fromMonth,
    int toDay,
    String toMonth,
  );

  String get noPermissionForThis;
  String get canSwapAvatarLater;
  String get onePhoto;
  String get lessThanOneKm;
  String get veryClose;
  String get pickTheExactSpot;
  String get theseSlotsSuitBoth;
  String get nobodyNearbyYet;
  String get tennisCourtsGeneric;
  String get allOverpassServersFailed;
  String get bioHint;

  /// "Estos huecos os vienen bien a ti y a Antonio."
  String theseSlotsSuitYouAnd(String name);


  /// La distancia larga: "A 4 km" / "4 km away".
  String kmAway(String km);

}
