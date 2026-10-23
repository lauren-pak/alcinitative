import '../models/account.dart';
import '../models/event.dart';

/// In-person events and RSVPs. Firestore in the app, in memory in tests.
/// `firestore.rules` enforces who can create events, the capacity, the
/// waitlist, and the under-18 guardian rules.
abstract class EventsRepository {
  /// Events that haven't started yet, soonest first (cancelled ones too, so
  /// people who RSVPed can see that).
  Future<List<SportEvent>> upcoming();

  Future<SportEvent?> getEvent(String eventId);

  /// [me]'s RSVP for [eventId], or null.
  Future<Rsvp?> myRsvp(String eventId, Account me);

  /// Takes a spot, or joins the waitlist if the event is full. Under-18s
  /// must give [guardianName] and [guardianPhone] (with consent).
  Future<Rsvp> rsvp(
    Account me,
    SportEvent event, {
    bool supportPerson = false,
    String? guardianName,
    String? guardianPhone,
  });

  /// Moves [me] from the waitlist into a spot that opened up. Throws if
  /// the event is still full.
  Future<Rsvp> claimSpot(Account me, SportEvent event);

  /// Gives up [me]'s spot or waitlist place.
  Future<void> cancelRsvp(Account me, SportEvent event);

  /// Events [me] had a spot at that have already started, newest first.
  /// They count towards streaks and badges.
  Future<List<SportEvent>> attended(Account me);

  /// Cancels all of [me]'s upcoming RSVPs, freeing their spots. Part of
  /// account deletion, before the contributions are deleted.
  Future<void> cancelAllMyRsvps(Account me);

  /// Whether [uid] is listed in `organisers` (added in the Firebase console).
  Future<bool> isOrganiser(String uid);

  Future<SportEvent> createEvent(Account organiser, EventDraft draft);

  /// Marks the event cancelled. RSVPs stay so people can see it.
  Future<void> cancelEvent(SportEvent event);

  /// Everyone who RSVPed (organisers only), going first.
  Future<List<Rsvp>> rsvpsFor(String eventId);
}
