import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/event.dart';
import 'events_repository.dart';

/// Events in Cloud Firestore:
/// - `events/{eventId}`: the event, readable by members, written by
///   organisers. `goingCount` moves by one in the same transaction as an
///   RSVP, which the rules check.
/// - `events/{eventId}/rsvps/{uid}`: a member's RSVP, readable only by them
///   and organisers. Recorded in the member's `contributions` so account
///   deletion removes it.
class FirestoreEventsRepository implements EventsRepository {
  FirestoreEventsRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');
  DocumentReference<Map<String, dynamic>> _rsvp(String eventId, String uid) =>
      _events.doc(eventId).collection('rsvps').doc(uid);
  CollectionReference<Map<String, dynamic>> _contributions(String uid) =>
      _db.collection('users').doc(uid).collection('contributions');

  @override
  Future<List<SportEvent>> upcoming() async {
    final snapshot = await _events
        .where('startsAt', isGreaterThan: Timestamp.now())
        .orderBy('startsAt')
        .limit(50)
        .get();
    return [for (final d in snapshot.docs) _eventFrom(d.id, d.data())];
  }

  @override
  Future<SportEvent?> getEvent(String eventId) async {
    final data = (await _events.doc(eventId).get()).data();
    return data == null ? null : _eventFrom(eventId, data);
  }

  @override
  Future<Rsvp?> myRsvp(String eventId, Account me) async {
    final data = (await _rsvp(eventId, me.uid).get()).data();
    return data == null ? null : _rsvpFrom(eventId, data);
  }

  @override
  Future<Rsvp> rsvp(
    Account me,
    SportEvent event, {
    bool supportPerson = false,
    String? guardianName,
    String? guardianPhone,
  }) async {
    final minor = EventRules.needsGuardian(me);
    final eventRef = _events.doc(event.id);
    final ref = _rsvp(event.id, me.uid);
    final status = await _db.runTransaction<RsvpStatus>((tx) async {
      final current = _eventFrom(event.id, (await tx.get(eventRef)).data()!);
      final status = current.isFull ? RsvpStatus.waitlist : RsvpStatus.going;
      tx.set(ref, {
        'uid': me.uid,
        'name': me.profile.name,
        'status': status.name,
        'supportPerson': supportPerson,
        'minor': minor,
        // Only under-18s give a guardian's details (data minimisation).
        if (minor) ...{
          'guardianName': guardianName!.trim(),
          'guardianPhone': guardianPhone!.trim(),
          'guardianConsent': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (status == RsvpStatus.going) {
        tx.update(eventRef, {'goingCount': FieldValue.increment(1)});
      }
      tx.set(_contributions(me.uid).doc(), {'path': ref.path});
      return status;
    });
    return Rsvp(
      uid: me.uid,
      eventId: event.id,
      name: me.profile.name,
      status: status,
      createdAt: DateTime.now(),
      supportPerson: supportPerson,
      minor: minor,
      guardianName: minor ? guardianName : null,
      guardianPhone: minor ? guardianPhone : null,
    );
  }

  @override
  Future<Rsvp> claimSpot(Account me, SportEvent event) async {
    final eventRef = _events.doc(event.id);
    final ref = _rsvp(event.id, me.uid);
    await _db.runTransaction<void>((tx) async {
      final current = _eventFrom(event.id, (await tx.get(eventRef)).data()!);
      if (current.isFull) throw StateError('Still full');
      tx.update(ref, {'status': RsvpStatus.going.name});
      tx.update(eventRef, {'goingCount': FieldValue.increment(1)});
    });
    return (await myRsvp(event.id, me))!;
  }

  @override
  Future<void> cancelRsvp(Account me, SportEvent event) async {
    final ref = _rsvp(event.id, me.uid);
    await _db.runTransaction<void>((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) return;
      tx.delete(ref);
      if (data['status'] == RsvpStatus.going.name) {
        tx.update(_events.doc(event.id), {
          'goingCount': FieldValue.increment(-1),
        });
      }
    });
  }

  /// IDs of events [me] RSVPed to, from their contributions.
  Future<Set<String>> _myEventIds(Account me) async {
    final contributions = await _contributions(me.uid).get();
    return {
      for (final c in contributions.docs)
        if ((c.data()['path'] as String? ?? '').split('/') case [
          'events',
          final eventId,
          'rsvps',
          _,
        ])
          eventId,
    };
  }

  @override
  Future<List<SportEvent>> attended(Account me) async {
    final ids = await _myEventIds(me);
    final pairs = await Future.wait([
      for (final id in ids) Future.wait([getEvent(id), myRsvp(id, me)]),
    ]);
    return [
      for (final [event as SportEvent?, rsvp as Rsvp?] in pairs)
        if (event != null &&
            event.hasStarted &&
            !event.cancelled &&
            (rsvp?.isGoing ?? false))
          event,
    ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  @override
  Future<void> cancelAllMyRsvps(Account me) async {
    final eventIds = await _myEventIds(me);
    for (final id in eventIds) {
      final event = await getEvent(id);
      // Past events: the RSVP is just deleted with the other contributions.
      if (event == null || event.hasStarted) continue;
      await cancelRsvp(me, event);
    }
  }

  @override
  Future<bool> isOrganiser(String uid) async {
    try {
      return (await _db.collection('organisers').doc(uid).get()).exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<SportEvent> createEvent(Account organiser, EventDraft draft) async {
    final ref = _events.doc();
    await ref.set({
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'sport': draft.sport,
      'startsAt': Timestamp.fromDate(draft.startsAt!),
      'endsAt': Timestamp.fromDate(draft.endsAt!),
      'area': draft.area.trim(),
      'meetingPoint': draft.meetingPoint.trim(),
      'accessibility': draft.accessibility.trim(),
      'safeguardingLead': draft.safeguardingLead.trim(),
      'capacity': draft.capacity,
      'goingCount': 0,
      'adultsOnly': draft.adultsOnly,
      'cancelled': false,
      'createdBy': organiser.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return (await getEvent(ref.id))!;
  }

  @override
  Future<void> cancelEvent(SportEvent event) =>
      _events.doc(event.id).update({'cancelled': true});

  @override
  Future<List<Rsvp>> rsvpsFor(String eventId) async {
    final snapshot = await _events.doc(eventId).collection('rsvps').get();
    final list = [for (final d in snapshot.docs) _rsvpFrom(eventId, d.data())]
      ..sort((a, b) {
        if (a.isGoing != b.isGoing) return a.isGoing ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }

  static SportEvent _eventFrom(String id, Map<String, dynamic> d) => SportEvent(
    id: id,
    title: d['title'] as String? ?? '',
    description: d['description'] as String? ?? '',
    sport: d['sport'] as String?,
    startsAt: _date(d['startsAt']),
    endsAt: _date(d['endsAt']),
    area: d['area'] as String? ?? '',
    meetingPoint: d['meetingPoint'] as String? ?? '',
    accessibility: d['accessibility'] as String? ?? '',
    safeguardingLead: d['safeguardingLead'] as String? ?? '',
    capacity: (d['capacity'] as num?)?.toInt() ?? 0,
    goingCount: (d['goingCount'] as num?)?.toInt() ?? 0,
    adultsOnly: d['adultsOnly'] as bool? ?? false,
    cancelled: d['cancelled'] as bool? ?? false,
  );

  static Rsvp _rsvpFrom(String eventId, Map<String, dynamic> d) => Rsvp(
    uid: d['uid'] as String,
    eventId: eventId,
    name: d['name'] as String? ?? '',
    status: d['status'] == RsvpStatus.going.name
        ? RsvpStatus.going
        : RsvpStatus.waitlist,
    createdAt: _date(d['createdAt']),
    supportPerson: d['supportPerson'] as bool? ?? false,
    minor: d['minor'] as bool? ?? false,
    guardianName: d['guardianName'] as String?,
    guardianPhone: d['guardianPhone'] as String?,
  );

  static DateTime _date(Object? value) =>
      (value as Timestamp?)?.toDate() ?? DateTime.now();
}
