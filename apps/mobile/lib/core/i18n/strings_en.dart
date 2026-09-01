import 'strings.dart';

/// El inglés. **Traducción literal del castellano**, sin reescribir ni
/// "mejorar" nada por el camino: si una frase no acaba de funcionar, se
/// arregla primero en castellano y luego se traduce igual aquí. Si no, es
/// imposible saber si un texto cambió por la traducción o porque alguien lo
/// reescribió por su cuenta.
class StringsEn extends Strings {
  const StringsEn();

  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get retry => 'Retry';
  @override
  String get back => 'Back';
  @override
  String get skip => 'Skip';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';
  @override
  String get close => 'Close';
  @override
  String get delete => 'Delete';
  @override
  String get next => 'Next';
  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get getStarted => 'Get started';
  @override
  String get signIn => 'Sign in';
  @override
  String get createAccount => 'Create account';
  @override
  String get welcomeBack => 'Welcome back';
  @override
  String get createYourAccount => 'Create your account';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get repeatPassword => 'Repeat the password';
  @override
  String get newPassword => 'New password';
  @override
  String get forgotPassword => 'Forgotten your password?';
  @override
  String get noAccountRegister => 'No account yet? Sign up';
  @override
  String get haveAccountSignIn => 'Already have an account? Sign in';
  @override
  String get passwordChangedSignIn =>
      'Password changed. Sign in with the new one';
  @override
  String get couldNotCheckEmail => 'We could not check that email.';
  @override
  String get showPassword => 'Show password';
  @override
  String get hidePassword => 'Hide password';
  @override
  String get minEightChars => 'At least 8 characters';

  @override
  String get recoverPassword => 'Recover password';
  @override
  String get whatIsYourEmail => 'What is your email?';
  @override
  String get weSendYouACode =>
      'We will send you a code to choose a new password.';
  @override
  String get writeTheCode => 'Enter the code';
  @override
  String get codeSixDigitsFifteenMin =>
      'We have written to you with a 6-digit code. It expires in 15 minutes.';
  @override
  String get sendCode => 'Send code';
  @override
  String get changePassword => 'Change password';
  @override
  String get useAnotherEmail => 'Use another email';
  @override
  String get ifAccountExistsCodeSent =>
      'If that account exists, we have sent it a code';
  @override
  String get writeYourEmail => 'Enter your email';
  @override
  String get codeIsSixDigits => 'The code has 6 digits';
  @override
  String get passwordNeedsEightChars =>
      'The password needs at least 8 characters';
  @override
  String get changingClosesSessions =>
      'Changing it signs you out on all your devices.';

  @override
  String get verifyYourEmail => 'Verify your email';
  @override
  String get verify => 'Verify';
  @override
  String get resendCode => 'Resend code';
  @override
  String resendCodeIn(int seconds) => 'Resend code ($seconds s)';
  @override
  String get codeSent => 'We have sent you a code';
  @override
  String get codeResent => 'Code resent';
  @override
  String weWroteTo(String email) =>
      'We have written to you at $email. The code expires in 15 minutes.';

  @override
  String get tabDiscover => 'Discover';
  @override
  String get tabPartners => 'Partners';
  @override
  String get tabMatches => 'Matches';
  @override
  String get tabProfile => 'Profile';

  @override
  String get levelBeginner => 'Beginner';
  @override
  String get levelIntermediate => 'Intermediate';
  @override
  String get levelAdvanced => 'Advanced';
  @override
  String get levelCompetitive => 'Competitive';

  @override
  String get sportTennis => 'Tennis';
  @override
  String get sportRunning => 'Running';
  @override
  String get tennisMatch => 'Tennis match';
  @override
  String get runningSession => 'Run';
  @override
  String get matchNoun => 'match';
  @override
  String get runNoun => 'run';

  @override
  String get genderMale => 'Man';
  @override
  String get genderFemale => 'Woman';
  @override
  String get genderOther => 'Other';
  @override
  String get genderMalePlural => 'Men';
  @override
  String get genderFemalePlural => 'Women';
  @override
  String get genderOtherPlural => 'Others';

  @override
  String get intentionCompete => 'Compete';
  @override
  String get intentionTrain => 'Train';
  @override
  String get intentionLearn => 'Improve my level';
  @override
  String get intentionFun => 'Have fun';
  @override
  String get intentionCompeteDetail => 'Serious matches, with a score';
  @override
  String get intentionTrainDetail => 'Get into rhythm and keep fit';
  @override
  String get intentionLearnDetail =>
      'I am looking for someone better to raise my level';
  @override
  String get intentionFunDetail => 'No pressure, just for the love of playing';

  @override
  List<String> get weekdayNames => const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  @override
  List<String> get weekdayShort =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  @override
  List<String> get bandNames => const ['Morning', 'Afternoon', 'Evening'];
  @override
  List<String> get monthNames => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  @override
  String get notSet => 'Not set';

  @override
  String get today => 'Today';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String inDays(int days) => 'In $days days';
  @override
  String longDate(String weekday, int day, String month) =>
      '$weekday $day $month';
  @override
  String dateAtTime(String date, String time) => '$date at $time';

  @override
  String get thisPerson => 'this person';
  @override
  String get noName => 'No name';
  @override
  String get unmatch => 'Stop being partners';
  @override
  String unmatchConfirm(String name) =>
      'Are you sure you want to stop being partners with $name? The '
      'conversation will be deleted too, and it cannot be undone.';
  @override
  String get unmatchConfirmNoName =>
      'Are you sure you want to stop being partners? The conversation will be '
      'deleted too, and it cannot be undone.';
  @override
  String get yourPartners => 'Your partners';
  @override
  String get searchByName => 'Search by name...';
  @override
  String get noPartnersYet => 'You have no partners yet';
  @override
  String get noPartnersHint =>
      'When someone you gave "I want to play" gives it back to you, they will '
      'appear here and you will be able to talk.';
  @override
  String noResultsFor(String query) => 'No results for "$query"';
  @override
  String get awaitingYourAnswer => 'Waiting for your answer';
  @override
  String get withAPlan => 'With a plan';
  @override
  String get noPlansYet => 'No plans yet';
  @override
  String sectionCount(String title, int count) => '$title · $count';
  @override
  String get proposeAMatch => 'Propose a match';
  @override
  String get proposeARun => 'Propose going for a run';
  @override
  String get seeCourtsNearby => 'See courts nearby';
  @override
  String get reportSent => 'Report sent';
  @override
  String get couldNotSendReport => 'The report could not be sent.';
  @override
  String get couldNotSendMessage => 'The message could not be sent.';
  @override
  String get couldNotLoadMessages => 'The messages could not be loaded';
  @override
  String get noMessagesYet => 'No messages yet';
  @override
  String get playedOnce => 'You have played once';
  @override
  String playedNTimes(int times) => 'You have played $times times';
  @override
  String get notPlayedYet => 'You have not met up yet';
  @override
  String proposesYou(String when) => 'Proposes you $when';
  @override
  String awaitingTheirAnswer(String when) => 'Waiting for their answer · $when';

  @override
  String get waitingForAnswer => 'Waiting for an answer';
  @override
  String get youProposedAMatch => 'You proposed a match';
  @override
  String get awaitsYourAnswer => 'Awaits your answer';
  @override
  String get theyProposeAMatch => 'Proposes you a match';
  @override
  String get matchConfirmed => 'Match confirmed';
  @override
  String get itDidNotSuitThem => 'It did not suit them';
  @override
  String get proposalDeclined => 'Proposal declined';
  @override
  String get proposalCancelled => 'Proposal cancelled';
  @override
  String get theyWithdrewTheProposal => 'They withdrew the proposal';
  @override
  String get noSpecificPlace => 'No specific place';

  @override
  String get couldNotCompleteOperation =>
      'The operation could not be completed.';

  @override
  String get yourMatches => 'Your matches';
  @override
  String get nothingScheduled => 'You have nothing scheduled yet';
  @override
  String get nothingScheduledHint =>
      'When you propose playing to one of your partners (or they propose it '
      'to you), you will see it here.';
  @override
  String get waitingForYourAnswer => 'Waiting for an answer';
  @override
  String finishedCount(int count) => 'Finished ($count)';
  @override
  String howDidItGoCount(int count) => 'How did it go? ($count)';
  @override
  String get tellingItMakesLevelsMean =>
      'Telling it is what makes everyone else levels mean something.';
  @override
  String get didYouPlay => 'Did you get to play?';
  @override
  String get yesWePlayed => 'Yes';
  @override
  String get itCouldNotBe => 'No';
  @override
  String get howDidItEnd => 'Who won?';
  @override
  String get meWon => 'Me';
  @override
  String get itWasNotPlayed => 'Not played';
  @override
  String get unanswered => 'Unanswered';
  @override
  String sessionWith(String noun, String name) => '$noun with $name';
  @override
  String daysAgo(int days) => '$days days ago';
  @override
  String get yesterday => 'Yesterday';
  @override
  String wouldYouSayPlaysAt(String name, String level) =>
      'Would you say $name plays at $level level?';
  @override
  String get whichWouldYouSay => 'Which would you say it is?';

  @override
  String get meetUp => 'Meet-up';
  @override
  String get couldNotOpenChat => 'The chat could not be opened';
  @override
  String cancelTheSession(String noun) => 'Cancel the $noun?';
  @override
  String get withdrawTheProposal => 'Withdraw the proposal?';
  @override
  String cancelNoun(String noun) => 'Cancel $noun';
  @override
  String get withdraw => 'Withdraw';
  @override
  String willBeNotified(String name) =>
      '$name will be notified. You can propose another day whenever you want.';
  @override
  String proposalWillDisappearFor(String name) =>
      'The proposal will disappear for $name.';
  @override
  String get sessionCancelled => 'Meet-up cancelled';
  @override
  String get proposalWithdrawn => 'Proposal withdrawn';
  @override
  String get where => 'Where';
  @override
  String get whoYouPlayWith => 'Who you play with';
  @override
  String get openChat => 'Open chat';
  @override
  String get sessionConfirmed => 'Meet-up confirmed';
  @override
  String get notConfirmed => 'Not confirmed';
  @override
  String waitingFor(String name) => 'Waiting for $name';
  @override
  String get waitingYourAnswerShort => 'Waiting for your answer';
  @override
  String get noLongerPlayed => 'No longer happening';
  @override
  String get itWasCancelled => 'It was cancelled';
  @override
  String get alreadyStarted => 'Already started';
  @override
  String get inLessThanAnHour => 'In less than an hour';
  @override
  String inHours(int hours) => 'In $hours h';
  @override
  String inDaysShort(int days) => 'In $days days';
  @override
  String get missingWhereToPlay => 'You still need to decide where to play';
  @override
  String get missingCourtBooking => 'The court still needs booking';
  @override
  String get agreeWhereAndBook =>
      'You have agreed the day and the time, but not the place. Agree it in '
      'the chat and book the court.';
  @override
  String get appDoesNotBookCourts =>
      'MatchPoint does not book courts yet. You have closed the meet-up '
      'between you, but you still need to contact the club to rent the court.';
  @override
  String get seeClubOnMaps => 'See the club on Maps';
  @override
  String get couldNotOpenMap => 'The map could not be opened';
  @override
  String yearsPlaying(int years) => '$years years playing';
  @override
  String averageKm(String km) => '$km km on average';

  @override
  String get accept => 'Accept';
  @override
  String get decline => 'Decline';
  @override
  String get withdrawProposal => 'Withdraw proposal';

  @override
  String get statusConfirmed => 'Confirmed';
  @override
  String get statusDeclined => 'Declined';
  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get noExperienceYet =>
      'They have not filled in their experience yet.';

  @override
  String get settings => 'Settings';
  @override
  String get signOut => 'Sign out';
  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';
  @override
  String get deleteMyAccount => 'Delete my account';
  @override
  String get cannotBeUndone => 'It cannot be undone';
  @override
  String get account => 'Account';
  @override
  String get profile => 'Profile';
  @override
  String get location => 'Location';
  @override
  String get searchRadius => 'Search radius';
  @override
  String get searchRadiusHint =>
      'How far we look for people, from your location.';
  @override
  String get sports => 'Sports';
  @override
  String get sportsHint =>
      'What you play. It decides who you see in Discover and who sees you.';
  @override
  String get availability => 'Availability';
  @override
  String get whatDoYouCome => 'What you come for';
  @override
  String get whatTheyComeFor => 'What they come for';
  @override
  String get description => 'Description';
  @override
  String get notWritten => 'Not written';
  @override
  String get level => 'Level';
  @override
  String get experience => 'Experience';
  @override
  String get inviteSomeone => 'Invite someone';
  @override
  String get inviteSomeoneHint =>
      'The more people from your area, the more matches';
  @override
  String get preferNotToSay => 'I prefer not to say';
  @override
  String get intentionShownHint =>
      'It appears on your profile so people know what you are looking for. If '
      'you choose nothing, it is not shown.';
  @override
  String get aboutYou => 'About you';
  @override
  String get aboutMe => 'About me';
  @override
  String get mySports => 'My Sports';
  @override
  String get seeMyPublicProfile => 'See my public profile';
  @override
  String get seeProfile => 'See profile';
  @override
  String get changePhotos => 'Change photos';
  @override
  String get noProfile => 'No profile';
  @override
  String get couldNotLoadProfile => 'The profile could not be loaded';
  @override
  String get nothingWrittenYet => 'You have not written anything yet.';
  @override
  String get noSportsChosen => 'They have not chosen sports yet.';
  @override
  String get chooseSportsFirst => 'Choose your sports first';
  @override
  String get partners => 'Partners';
  @override
  String get matchesStat => 'Matches';
  @override
  String get matchStat => 'Match';
  @override
  String get wonStat => 'Won';
  @override
  String get verified => 'Verified';
  @override
  String get unverifiedTapToConfirm => 'Unverified — tap to confirm it';
  @override
  String get yearsPlayingTennis => 'Years playing tennis';
  @override
  String get club => 'Club';
  @override
  String get averagePaceLabel => 'Average pace (min:sec / km)';
  @override
  String get averagePaceHint => 'E.g. 4:30';
  @override
  String get averageDistanceLabel => 'Average distance (km)';
  @override
  String get averageDistanceHint => 'E.g. 10';
  @override
  String get tournamentsAchievements => 'Tournaments / achievements';
  @override
  String get achievementHint => 'E.g. Provincial champion 2024';
  @override
  String get couldNotSaveLocation => 'Your location could not be saved.';
  @override
  String get couldNotSaveRadius => 'The search radius could not be saved.';
  @override
  String get couldNotSaveSports => 'Your sports could not be saved.';
  @override
  String get couldNotSaveChanges => 'The changes could not be saved.';
  @override
  String get couldNotSaveDescription => 'Your description could not be saved.';
  @override
  String get couldNotSaveLevel => 'Your level could not be saved.';
  @override
  String get couldNotSaveExperience => 'Your experience could not be saved.';
  @override
  String maxCharsPerAchievement(int max) =>
      'At most $max characters per achievement';
  @override
  String maxAchievements(int max) => 'At most $max achievements';
  @override
  String clubMaxLength(int max) => 'The club cannot exceed $max characters';
  @override
  String maxCharsUsed(int max, int used) =>
      'At most $max characters (you have $used).';
  @override
  String averageKmLabel(String km) => '$km km on average';
  @override
  String pacePerKm(String pace) => '$pace min/km';
  @override
  String achievementsCount(int count) => '$count achievement(s)';
  @override
  String sportAndLevel(String sport, String level) => '$sport: $level';
  @override
  String kmValue(int km) => '$km km';

  @override
  String get report => 'Report';

  @override
  String get whereDoYouPlay => 'Where do you play?';
  @override
  String get postcodeHint =>
      'Enter your postcode and we will show you people near you.';
  @override
  String get postcode => 'Postcode';
  @override
  String get postcodeExample => '29639';
  @override
  String get postcodeNotFound =>
      'We could not find that postcode. Check it or search for your city by '
      'name.';
  @override
  String get couldNotSearchPostcode => 'The postcode could not be searched.';
  @override
  String get dontKnowSearchByCity => 'I do not know — search by city';
  @override
  String upToKm(int km) => 'Up to $km km away';
  @override
  String get onlyYourAreaIsUsed =>
      'We only use your area to work out distances. Nobody sees where you '
      'live: profiles only show how many kilometres away you are.';
  @override
  String get whichOfThese => 'Which of these?';
  @override
  String get lookingWhoPlaysAround => 'Looking at who plays around there…';
  @override
  String get nobodyHereYet => 'There is nobody around here yet';
  @override
  String get nobodyHereYetHint =>
      'You would be one of the first. We will let you know as soon as someone '
      'signs up nearby — and meanwhile you can widen the radius to look '
      'further.';
  @override
  String get onePersonPlayingHere => 'There is 1 person playing around here';
  @override
  String peoplePlayingHere(int count) =>
      'There are $count people playing around here';
  @override
  String get youWillSeeThemAfterProfile =>
      'You will be able to see them as soon as you finish creating your '
      'profile.';

  @override
  String get yourMatchStep => 'Your match';
  @override
  String get helpUsFindYourRival => 'Help us find your perfect rival.';
  @override
  String get whatIsYourLevel => 'What is your level?';
  @override
  String get whenCanYouUsuallyPlay => 'When can you usually play?';
  @override
  String get weUseItToShowWhoMatches =>
      'We use it to show you first whoever overlaps with you.';

  @override
  String get yourProfileStep => 'Your profile';
  @override
  String get displayName => 'Display name';
  @override
  String get birthDate => 'Date of birth';
  @override
  String get chooseDate => 'Choose date';
  @override
  String get gender => 'Gender';
  @override
  String get aboutYouHint =>
      'Mention whatever you think other profiles should know about you.';
  @override
  String get bioExample =>
      'I play on Tuesday afternoons near the centre. I am looking for someone '
      'steady rather than competitive.';

  @override
  String get chooseYourAvatar => 'Choose your avatar';
  @override
  String get avatarHint =>
      'If you prefer a photo of yourself, you can upload it later from your '
      'profile.';

  @override
  String get chooseWhereYouPlayFirst =>
      'Choose where you play so we can show you people near you';
  @override
  String get writeYourDisplayName =>
      'Enter the name you want to appear with';
  @override
  String displayNameTooLong(int max) =>
      'The name cannot exceed $max characters';
  @override
  String get chooseYourBirthDate => 'Choose your date of birth';
  @override
  String get couldNotCompleteSignUp => 'The sign-up could not be completed.';
  @override
  String get leaveSignUp => 'Leave the sign-up?';
  @override
  String get leaveSignUpHint =>
      'You are going back to the sign-in screen. Nothing you completed has '
      'been saved yet — no data already created is lost, but you will have to '
      'start the sign-up again.';
  @override
  String get createMyProfile => 'Create my profile';
  @override
  String get leave => 'Leave';

  @override
  String get sessionExpired => 'Your session has expired. Sign in again.';
  @override
  String get noLongerAvailable => 'This is no longer available.';
  @override
  String get tooManyRequests =>
      'You have made too many requests in a row. Wait a moment.';
  @override
  String get serverFailure =>
      'We could not complete the operation. Try again in a few seconds.';
  @override
  String get noConnection =>
      'No connection. Check your network and try again.';
  @override
  String get serverTooSlow => 'The server is taking too long. Try again.';

  @override
  String get deleteYourAccount => 'Delete your account';
  @override
  String get deleteCannotBeUndone =>
      'This cannot be undone. The following is deleted forever:';
  @override
  String get partnersAndConversations =>
      'Your partners and all your conversations';
  @override
  String get peopleWillStopSeeingYou =>
      'The people you were talking to will stop seeing you, and there is no '
      'way to recover any of this later.';
  @override
  String typeToConfirm(String word) => 'Type $word to confirm:';
  @override
  String get deleteAccount => 'Delete account';

  @override
  String get postcodeOrCity => 'Postcode or city';
  @override
  String get postcodeOrCityHint =>
      'Enter your postcode (29630) or the name of your city.';
  @override
  String get noResultsTryExactName =>
      'No results. Try the exact name of the place or your postcode.';

  @override
  String get thisIsHowTheyLook => 'This is how they will look';
  @override
  String get thisIsHowItLooks => 'This is how it will look';
  @override
  String get landscapeCropExplainerMany =>
      'MatchPoint uses landscape photos, so we crop them from the centre. '
      'Remove the ones you are not happy with.';
  @override
  String get landscapeCropExplainerOne =>
      'MatchPoint uses landscape photos, so we crop it from the centre. '
      'If it cuts off something important, choose another one.';
  @override
  String get discardAll => 'Discard all';
  @override
  String get chooseAnother => 'Choose another';
  @override
  String useTheseCount(int count) => 'Use these ($count)';
  @override
  String get useThisOne => 'Use this one';
  @override
  String maxPhotos(int max) => 'At most $max photos.';
  @override
  String get addPhoto => 'Add photo';
  @override
  String get takeAPhoto => 'Take a photo';
  @override
  String get chooseFromGallery => 'Choose from the gallery';
  @override
  String youCanChooseUpTo(int limit) => 'You can choose up to $limit';
  @override
  String get useAnAvatar => 'Use an avatar';
  @override
  String get avatarGalleryHint =>
      'Illustrations from the app, if you prefer not to show your face';

  @override
  String youOverlapCount(int count) => 'You overlap ($count)';
  @override
  String get onlyTheOtherPersonCan => 'Only the other person can';
  @override
  String onlyPersonCan(String name) => 'Only $name can';

  @override
  String get startWithWhenYouCanPlay => 'Start with when you can play';
  @override
  String get discoveryIntroBody =>
      'Mark the slots you usually have free and we will put whoever overlaps '
      'with you first. Tap someone to see their profile, or hit "I want to '
      'play" and, if they give it back, you can arrange a match.';
  @override
  String get youAreNowPartners => 'You are partners now!';
  @override
  String get keepLooking => 'Keep looking';
  @override
  String get sendMessage => 'Send message';
  @override
  String get organizeMatch => 'Organize game';
  @override
  String get couldNotOpenChatTryMatches =>
      'The chat could not be opened, try from Partners';
  @override
  String get chooseAtLeastOneSport =>
      'Choose at least one sport to be able to see profiles';
  @override
  String get filtersDecideWhoWeShow =>
      'They decide who we show you. The distance radius is changed in '
      'Settings, next to your location.';
  @override
  String get whenICanPlay => 'When I can play';
  @override
  String get anyTime => 'Any time';
  @override
  String get ageRange => 'Age range';
  @override
  String ageRangeValue(int from, int to) => '$from - $to years';
  @override
  String get sportsYouWantToSee => 'Sports you want to see';
  @override
  String get notNow => 'Not now';
  @override
  String playWith(String name) => 'Play with $name';
  @override
  String get iWantToPlay => 'I want to play';
  @override
  String get noSharedSlots => 'You do not overlap in any time slot';
  @override
  String get oneSharedSlot => 'You overlap in 1 time slot';
  @override
  String sharedSlots(int count) => 'You overlap in $count time slots';
  @override
  String get thisWeekend => 'This weekend';
  @override
  String get weekdayEvenings => 'Weekdays, afternoons';
  @override
  String get weekdayMornings => 'Weekdays, mornings';
  @override
  String get whenCanYouPlay => 'When can you play?';
  @override
  String get whenFilterHint =>
      'We show you first whoever suits the same times as you. Mark the slots '
      'you usually have free.';
  @override
  String get clearFilter => 'Clear filter';
  @override
  String seeWhoCan(int count) => 'See who can ($count)';

  @override
  String get proposalSent => 'Proposal sent';
  @override
  String get meetingPoint => 'Meeting point';
  @override
  String get whereDoYouPlayQ => 'Where do you play?';
  @override
  String get meetingPointQ => 'Meeting point?';
  @override
  String get markExactSpot =>
      'Mark the exact spot on the map — much more useful than just naming the '
      'town.';
  @override
  String get chooseClubOrMark =>
      'Choose one of the nearby clubs, or mark the exact spot on the map.';
  @override
  String get chooseNearbyClub => 'Choose a nearby club';
  @override
  String get markOnTheMap => 'Mark on the map';
  @override
  String get setLocationInSettings =>
      'Set your location in Settings to be able to choose a place on the map.';
  @override
  String get searchPlaceByName => 'Search for a place by name';
  @override
  String get whereYouPlay => 'Where you play';
  @override
  String get filterByName => 'Filter by name...';
  @override
  String get mapServiceBusy =>
      'The map service is overloaded right now. Try again in a few seconds.';
  @override
  String get noPlaceWithThatName => 'No place with that name';
  @override
  String get tryAnotherPartOfName => 'Try another part of the name.';
  @override
  String get osmDataMayBeMissing =>
      'The data comes from OpenStreetMap, so some courts may be missing. You '
      'can widen the search or mark the spot on the map.';
  @override
  String searchUpToKm(int km) => 'Search up to $km km';
  @override
  String get noNameInOsmYouConfirm =>
      'No name in OpenStreetMap · you confirm it';
  @override
  String get tennisCourts => 'Tennis courts';
  @override
  String courtsCount(int count) => '$count courts';
  @override
  String get whatIsThisPlaceCalled => 'What is this place called?';
  @override
  String osmHasCourtsNoName(String courts) =>
      'OpenStreetMap has $courts here, but with no name. Give it one so the '
      'other person knows where it is — the exact location is already '
      'included.';
  @override
  String get placeName => 'Place name';
  @override
  String get useThisPlace => 'Use this place';
  @override
  String get atWhatTime => 'At what time?';
  @override
  String get hoursTheyCanUsually => 'Hours they can usually make';
  @override
  String personUsuallyCanAtTheseHours(String name) =>
      '$name can usually make these hours';
  @override
  String proposeAt(String time) => 'Propose at $time';
  @override
  String get whatDay => 'What day?';
  @override
  String get daysTheyUsuallyHaveFree => 'Days they usually have free';
  @override
  String personUsuallyFreeTheseDays(String name) =>
      '$name usually has these days free';

  @override
  String get couldNotLoadYourProfile =>
      'Your profile could not be loaded. Try again.';
  @override
  String get emailAlreadyInUse => 'That email is already in use';
  @override
  String get emailLooksInvalid => 'That email does not look valid';
  @override
  String get passwordAtLeastEight =>
      'The password must have at least 8 characters';
  @override
  String get passwordAtMost72 => 'The password cannot exceed 72 characters';
  @override
  String get passwordsDoNotMatch => 'The passwords do not match';
  @override
  String get couldNotSignIn => 'You could not be signed in';
  @override
  String get couldNotSendCode => 'The code could not be sent';
  @override
  String get couldNotChangePassword => 'The password could not be changed';
  @override
  String get later => 'Later';
  @override
  String get inviteMessage =>
      'Shall we play? I am using MatchPoint, an app to find someone to play '
      'tennis with near home and at the times that suit you.';

  @override
  String get yourProfileAndPhotos => 'Your profile and your photos';
  @override
  String get agreedSessions => 'The matches and runs you have agreed';
  @override
  String get yourLevelExperiencePreferences =>
      'Your level, your experience and your preferences';

  @override
  String get welcomeTagline =>
      'Find someone to play tennis with: people at your level, near you, and '
      'available when you are.';
  @override
  String get whenDoYouMeet => 'When do you meet?';
  @override
  String get chooseAnotherDay => 'Choose another day';
  @override
  String get couldNotLoadPartners => 'Your partners could not be loaded.';
  @override
  String get noPartnersAtAll => 'You have no partners yet';
  @override
  String get whoDoYouProposeItTo => 'Who do you propose it to?';
  @override
  String get proposeMatchHere => 'Propose a match here';
  @override
  String get shareClubAndTimeHint =>
      'the club and the time to your partner, and you confirm it between you.';
  @override
  String get couldNotRegisterDecision => 'Your decision could not be recorded';
  @override
  String get couldNotOpenConversation =>
      'The conversation could not be opened';
  @override
  String get conversationNoLongerAvailable =>
      'This conversation is no longer available';
  @override
  String get couldNotMarkAsRead => 'They could not be marked as read';
  @override
  String get couldNotSaveDescriptionShort =>
      'The description could not be saved';
  @override
  String get tryMoreFreeSlots =>
      'Try more free slots, or clear the filters to see everyone nearby.';
  @override
  String get widenTheRadius =>
      'Widen the search radius to see people further away. We will let you '
      'know when someone new signs up in your area.';
  @override
  String get addAnythingUseful =>
      'Add anything that might interest your future partner.';
  @override
  String get couldNotReadYourLocation => 'We could not read your location.';
  @override
  String get noLocationInProfile =>
      'You have no location in your profile yet.';
  @override
  String tennisCourtsAt(String place) => 'Tennis courts · $place';

  @override
  String get placeNotFound => 'Place not found';
  @override
  String get couldNotSearchPlaces => 'Places could not be searched.';

  @override
  String mapIsAtFallback(String place) =>
      'We could not read your location. This is $place, not your area.';
  @override
  String noLocationSearchAbove(String place) =>
      'You have no location in your profile yet. This is $place: search for '
      'your area above.';
  @override
  String get weDoNotCheckAvailability =>
      'We do not check whether a court is free at that time — you propose the '
      'club and the time to your partner, and you confirm it between you.';

  @override
  String get findYourMatch => 'Find your match';

  @override
  String get anyLevel => 'Any';
  @override
  String get levelSheetHint =>
      'An even match is a better match. It is the level each person says '
      'they have, not a ranking.';
  @override
  String get atNights => 'In the evenings';
  @override
  String get seeEveryone => 'See everyone';

  @override
  String get reportUser => 'Report user';
  @override
  String get chooseAnAvatar => 'Choose an avatar';
  @override
  String get couldNotUploadAllPhotos => 'Not all the photos could be uploaded.';
  @override
  String get profileNeedsOnePhoto => 'Your profile needs at least one photo.';
  @override
  String get couldNotDeletePhoto => 'The photo could not be deleted';
  @override
  String get yourPhotos => 'Your photos';
  @override
  String get photos => 'Photos';
  @override
  String get writeAMessage => 'Write a message...';
  @override
  String get couldNotSaveFilters => 'The filters could not be saved.';
  @override
  String get filters => 'Filters';
  @override
  String get change => 'Change';
  @override
  String get referenceOptional => 'Landmark (optional)';
  @override
  String get referenceHint => 'E.g. park entrance, next to the fountain';
  @override
  String get useThisSpot => 'Use this spot';
  @override
  String get proposeWithoutPlace => 'Propose without a place';
  @override
  String get couldNotLoadList => 'The list could not be loaded';
  @override
  String get couldNotCreateAccount => 'The account could not be created';
  @override
  String get couldNotVerifyEmail => 'The email could not be verified';
  @override
  String get tennisClubsNearby => 'Tennis clubs nearby';
  @override
  String get searchCityOrArea => 'Search city or area...';
  @override
  String get clearFilters => 'Clear filters';
  @override
  String get widenRadius => 'Widen the radius';
  @override
  String get inviteSomeoneYouPlayWith => 'Invite someone you play with';
  @override
  String get couldNotLoadProfiles => 'The profiles could not be loaded';
  @override
  String get couldNotUnmatch => 'The match could not be undone';
  @override
  String get couldNotSendProposal => 'The proposal could not be sent';
  @override
  String get couldNotAnswerProposal => 'The proposal could not be answered';
  @override
  String get couldNotLoadSessions => 'Your meet-ups could not be loaded';
  @override
  String get couldNotLoadHistory => 'The history could not be loaded';
  @override
  String get couldNotSaveAnswer => 'Your answer could not be saved';
  @override
  String get couldNotSave => 'It could not be saved';
  @override
  String get couldNotSaveAvailability => 'Your availability could not be saved';
  @override
  String get couldNotSavePreferences => 'Your preferences could not be saved';
  @override
  String get couldNotDeleteAccountMsg => 'The account could not be deleted';

  @override
  String get reasonInappropriate => 'Inappropriate behaviour';
  @override
  String get reasonFakeProfile => 'Fake profile';
  @override
  String get reasonSpam => 'Spam or advertising';
  @override
  String get reasonOffensive => 'Offensive content';
  @override
  String get reasonOther => 'Other';
  @override
  String get youWon => 'Won';
  @override
  String get youLost => 'Lost';
  @override
  String get itWasADraw => 'Draw';

  @override
  String get confirm => 'Confirm';

  @override
  List<String> get weekdayInitials =>
      const ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];

  @override
  String get noClubsAround =>
      'No clubs registered around here. Try searching another city.';

  @override
  String get openInMaps => 'Open in Maps';
}
