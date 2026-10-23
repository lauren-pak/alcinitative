import 'account.dart';
import 'sign_up_data.dart';

/// An in-person social sporting event, created by an organiser (listed in
/// `organisers/{uid}`). Members RSVP in the app. See `docs/events.md`.
class SportEvent {
  const SportEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.area,
    required this.capacity,
    required this.safeguardingLead,
    this.description = '',
    this.sport,
    this.meetingPoint = '',
    this.accessibility = '',
    this.goingCount = 0,
    this.adultsOnly = false,
    this.cancelled = false,
  });

  final String id;
  final String title;
  final String description;

  /// One of [sports], or null for any sport.
  final String? sport;
  final DateTime startsAt;
  final DateTime endsAt;

  /// The neighbourhood or venue name shown in the list, e.g. "Kallang".
  final String area;

  /// Where exactly to meet, e.g. "Outside the stadium main entrance".
  final String meetingPoint;

  /// Step-free access, quiet space, support workers welcome, and so on.
  final String accessibility;

  /// The person responsible for safety on the day, named on every event.
  final String safeguardingLead;
  final int capacity;
  final int goingCount;

  /// Under-18s can't RSVP. Otherwise they can, with a guardian's consent.
  final bool adultsOnly;
  final bool cancelled;

  bool get isFull => goingCount >= capacity;
  int get spotsLeft => capacity - goingCount < 0 ? 0 : capacity - goingCount;
  bool get hasStarted => !startsAt.isAfter(DateTime.now());

  SportEvent copyWith({int? goingCount, bool? cancelled}) => SportEvent(
    id: id,
    title: title,
    description: description,
    sport: sport,
    startsAt: startsAt,
    endsAt: endsAt,
    area: area,
    meetingPoint: meetingPoint,
    accessibility: accessibility,
    safeguardingLead: safeguardingLead,
    capacity: capacity,
    goingCount: goingCount ?? this.goingCount,
    adultsOnly: adultsOnly,
    cancelled: cancelled ?? this.cancelled,
  );
}

enum RsvpStatus { going, waitlist }

/// A member's place at an event. Only the member and organisers can read it.
class Rsvp {
  const Rsvp({
    required this.uid,
    required this.eventId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.supportPerson = false,
    this.minor = false,
    this.guardianName,
    this.guardianPhone,
  });

  final String uid;
  final String eventId;
  final String name;
  final RsvpStatus status;
  final DateTime createdAt;

  /// Bringing a carer or support person (doesn't take a spot).
  final bool supportPerson;

  /// Under 18 when they RSVPed; then a guardian's details are required.
  final bool minor;
  final String? guardianName;
  final String? guardianPhone;

  bool get isGoing => status == RsvpStatus.going;
}

/// What an organiser fills in to create an event.
class EventDraft {
  String title = '';
  String description = '';
  String? sport;
  DateTime? startsAt;
  DateTime? endsAt;
  String area = '';
  String meetingPoint = '';
  String accessibility = '';
  String safeguardingLead = '';
  int capacity = 20;
  bool adultsOnly = false;
}

/// RSVP rules shared by the app and mirrored in `firestore.rules`.
class EventRules {
  /// Null if [member] may RSVP to [event], or the reason they can't.
  static String? rsvpBlockedFor(Account member, SportEvent event) {
    if (event.cancelled) return 'This event was cancelled.';
    if (event.hasStarted) return 'This event has already started.';
    if (event.adultsOnly && member.profile.isMinorOn(DateTime.now())) {
      return 'This event is for over-18s only.';
    }
    return null;
  }

  /// Under-18s need a parent or guardian's consent and contact details.
  static bool needsGuardian(Account member) =>
      member.profile.isMinorOn(DateTime.now());

  /// A phone number that the rules accept: digits, spaces and +, 8 to 16.
  static bool validPhone(String phone) =>
      RegExp(r'^[+0-9 ]{8,16}$').hasMatch(phone.trim());
}

/// Display helper: the sport, or "Any sport".
String eventSportLabel(SportEvent event) => event.sport == null
    ? 'Any sport'
    : event.sport == otherSport
    ? 'Other sports'
    : event.sport!;
