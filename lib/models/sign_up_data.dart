import 'display_mode.dart';

enum UserRole {
  athlete(
    'Athlete',
    'Share your experiences and give advice to other athletes.',
  ),
  public(
    'General public',
    'Follow athletes, learn from them and ask questions.',
  );

  const UserRole(this.label, this.description);
  final String label;
  final String description;
}

enum SignUpMethod {
  google('Google'),
  phone('Phone number'),
  email('Email');

  const SignUpMethod(this.label);
  final String label;
}

/// Optional programme an athlete belongs to.
enum AthleteCategory {
  national('National athlete'),
  paralympic('Paralympic athlete'),
  specialOlympics('Special Olympics athlete');

  const AthleteCategory(this.label);
  final String label;
}

/// Huddle categories: positive spotlights on athletes' own experience.
/// The old problem-focused topics (injury, nutrition, competition) were
/// replaced; posts that still use them are read as [legacy] says.
enum Topic {
  training('Training wins'),
  mindset('Mindset'),
  gameDay('Game day'),
  teamLife('Team & life');

  const Topic(this.label);
  final String label;

  /// Old stored names and the category they now belong to.
  static const legacy = {
    'injury': Topic.training,
    'nutrition': Topic.training,
    'competition': Topic.gameDay,
  };

  /// Every name stored in Firestore that means this category, for queries.
  List<String> get storedNames => [
    name,
    for (final e in legacy.entries)
      if (e.value == this) e.key,
  ];

  /// Reads a stored name, including old ones. Null if unknown.
  static Topic? fromStored(Object? stored) {
    for (final t in values) {
      if (t.name == stored) return t;
    }
    return legacy[stored];
  }
}

enum CompetitionLevel {
  school('School'),
  club('Club'),
  regional('Regional'),
  national('National'),
  elite('Elite / Pro');

  const CompetitionLevel(this.label);
  final String label;
}

// Includes the Special Olympics Singapore sports listed on the Inclusive Sport
// directory (inclusivesport.gov.sg): athletics, badminton, basketball, bocce,
// bowling, football, swimming.
const sports = [
  'Athletics',
  'Badminton',
  'Basketball',
  'Bocce',
  'Bowling',
  'Cricket',
  'Cycling',
  'Football',
  'Gymnastics',
  'Hockey',
  'Martial arts',
  'Netball',
  'Rowing',
  'Rugby',
  'Swimming',
  'Tennis',
  'Volleyball',
  otherSport,
];

/// Last entry in [sports]; choosing it asks the athlete to type their sport.
const otherSport = 'Other';

/// Youngest age allowed to sign up.
const minimumAge = 13;

/// Members younger than this get the under-18 protections.
const adultAge = 18;

/// Age in whole years on [today].
int ageOn(DateTime dateOfBirth, DateTime today) {
  var age = today.year - dateOfBirth.year;
  final hadBirthdayThisYear =
      today.month > dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}

/// The date someone turns 18, when under-18 protections stop.
DateTime adultFromBirthDate(DateTime dateOfBirth) => DateTime.utc(
  dateOfBirth.year + adultAge,
  dateOfBirth.month,
  dateOfBirth.day,
);

/// A member's profile. Filled in step by step during sign-up, then saved.
///
/// [email] and [phone] are only shown back to the member; they live in
/// Firebase Auth, not in the profile database.
class SignUpData {
  UserRole? role;
  SignUpMethod? method;
  String email = '';
  String phone = '';
  String name = '';
  DateTime? dateOfBirth;
  String? sport;

  /// Typed in when [sport] is [otherSport].
  String customSport = '';
  CompetitionLevel? level;
  AthleteCategory? category;
  final Set<Topic> topics = {};

  /// When the member agreed to the Privacy Notice (PDPA consent).
  DateTime? consentGivenAt;

  /// Standard or Easy view. Private: only the member sees it.
  DisplayMode displayMode = DisplayMode.standard;

  /// Topics hidden from this member's feed. Private.
  final Set<Topic> mutedTopics = {};

  /// Shown in Find athlete (name search and browsing by sport and
  /// programme). Adult athletes only ([canBeFindableOn]): on by default for
  /// them, and they can turn it off in Settings. Never for under-18s.
  bool findable = true;

  /// Only adult athletes can be found in search. Under-18s can still share
  /// their athlete ID.
  bool canBeFindableOn(DateTime now) =>
      role == UserRole.athlete && !isMinorOn(now);

  /// The sport to display, using the typed-in name for "Other".
  String? get sportName => sport == otherSport ? customSport : sport;

  bool isMinorOn(DateTime today) =>
      dateOfBirth != null && ageOn(dateOfBirth!, today) < adultAge;

  SignUpData copy() => SignUpData()
    ..role = role
    ..method = method
    ..email = email
    ..phone = phone
    ..name = name
    ..dateOfBirth = dateOfBirth
    ..sport = sport
    ..customSport = customSport
    ..level = level
    ..category = category
    ..topics.addAll(topics)
    ..consentGivenAt = consentGivenAt
    ..displayMode = displayMode
    ..mutedTopics.addAll(mutedTopics)
    ..findable = findable;

  /// Copies the fields editable in Settings from [edited] (a [copy] that
  /// was changed and saved), so every screen holding this profile sees them.
  void applyEditsFrom(SignUpData edited) {
    name = edited.name;
    sport = edited.sport;
    customSport = edited.customSport;
    level = edited.level;
    category = edited.category;
    topics
      ..clear()
      ..addAll(edited.topics);
    displayMode = edited.displayMode;
    findable = edited.findable;
  }
}
