enum UserRole {
  athlete('Athlete', 'Share your experiences and give advice to other athletes.'),
  public('General public', 'Follow athletes, learn from them and ask questions.');

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

enum Topic {
  injury('Injury'),
  training('Training'),
  nutrition('Sports nutrition'),
  competition('Competition');

  const Topic(this.label);
  final String label;
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
  final hadBirthdayThisYear = today.month > dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}

/// The date someone turns 18, when under-18 protections stop.
DateTime adultFromBirthDate(DateTime dateOfBirth) =>
    DateTime.utc(dateOfBirth.year + adultAge, dateOfBirth.month, dateOfBirth.day);

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
    ..consentGivenAt = consentGivenAt;
}
