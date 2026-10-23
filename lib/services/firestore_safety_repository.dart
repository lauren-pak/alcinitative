import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/moderation.dart';
import '../models/post.dart';
import 'safety_repository.dart';

/// Reporting, blocking and moderator checks in Firestore. See the
/// moderation section of `firestore.rules`.
class FirestoreSafetyRepository implements SafetyRepository {
  FirestoreSafetyRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _blocked(String uid) =>
      _db.collection('users').doc(uid).collection('blocked');
  CollectionReference<Map<String, dynamic>> _contributions(String uid) =>
      _db.collection('users').doc(uid).collection('contributions');

  @override
  Future<bool> reportPost(
    Account reporter,
    Post post,
    ReportReason reason, {
    String details = '',
  }) => _report(
    reporter,
    _db.collection('posts').doc(post.id),
    post.text,
    reason,
    details,
  );

  @override
  Future<bool> reportReply(
    Account reporter,
    Reply reply,
    ReportReason reason, {
    String details = '',
  }) => _report(
    reporter,
    _db
        .collection('posts')
        .doc(reply.postId)
        .collection('replies')
        .doc(reply.id),
    reply.text,
    reason,
    details,
  );

  Future<bool> _report(
    Account reporter,
    DocumentReference<Map<String, dynamic>> target,
    String text,
    ReportReason reason,
    String details,
  ) {
    final report = _db
        .collection('reports')
        .doc(reportId(target.path, reporter.uid));
    return _db.runTransaction<bool>((tx) async {
      if ((await tx.get(report)).exists) return false;
      final data = (await tx.get(target)).data() ?? const {};
      final count = ((data['reportCount'] as num?)?.toInt() ?? 0) + 1;
      tx.set(report, {
        'reporterUid': reporter.uid,
        'targetPath': target.path,
        'targetText': text.length > 500 ? text.substring(0, 500) : text,
        'reason': reason.name,
        'details': details.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(target, {
        'reportCount': count,
        // Enough reports: hide it until a moderator has looked.
        if (count >= reportsToHide && data['status'] == 'visible') ...{
          'status': ContentStatus.held.name,
          'holdReason': HoldReason.reports.name,
        },
      });
      // So deleting the account also deletes the member's reports.
      tx.set(_contributions(reporter.uid).doc(), {'path': report.path});
      return true;
    });
  }

  @override
  Future<Set<String>> blockedUids(Account me) async => {
    for (final d in (await _blocked(me.uid).get()).docs) d.id,
  };

  @override
  Future<List<BlockedMember>> blockedMembers(Account me) async => [
    for (final d in (await _blocked(me.uid).get()).docs)
      BlockedMember(uid: d.id, name: d.data()['name'] as String? ?? ''),
  ];

  @override
  Future<void> block(Account me, Author other) async {
    final doc = _blocked(me.uid).doc(other.uid);
    final batch = _db.batch()
      ..set(doc, {
        'name': other.name,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_contributions(me.uid).doc(), {'path': doc.path});
    await batch.commit();
  }

  @override
  Future<void> unblock(Account me, String uid) =>
      _blocked(me.uid).doc(uid).delete();

  @override
  Future<bool> isModerator(String uid) async {
    try {
      return (await _db.collection('moderators').doc(uid).get()).exists;
    } on FirebaseException {
      return false;
    }
  }
}

/// The moderator queue in Firestore.
class FirestoreModerationRepository implements ModerationRepository {
  FirestoreModerationRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static DateTime _date(Object? v) =>
      (v as Timestamp?)?.toDate() ?? DateTime.now();

  static HoldReason? _reason(Object? name) {
    for (final r in HoldReason.values) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// The real author, including for anonymous posts (moderators may read
  /// `postAuthors`).
  Future<String?> _authorOf(String postId) async =>
      (await _db.collection('postAuthors').doc(postId).get()).data()?['uid']
          as String?;

  @override
  Future<List<QueueItem>> heldPosts() async {
    final snapshot = await _db
        .collection('posts')
        .where('status', isEqualTo: ContentStatus.held.name)
        .orderBy('createdAt')
        .get();
    return Future.wait([
      for (final doc in snapshot.docs)
        () async {
          final d = doc.data();
          final uid = d['authorUid'] as String? ?? await _authorOf(doc.id);
          return QueueItem(
            path: doc.reference.path,
            text: d['text'] as String? ?? '',
            createdAt: _date(d['createdAt']),
            holdReason: _reason(d['holdReason']),
            authorName:
                d['authorName'] as String? ??
                (d['anonymous'] == true ? 'Anonymous post' : null),
            authorUid: uid,
            reportCount: (d['reportCount'] as num?)?.toInt() ?? 0,
          );
        }(),
    ]);
  }

  @override
  Future<List<QueueItem>> heldReplies() async {
    final snapshot = await _db
        .collectionGroup('replies')
        .where('status', isEqualTo: ContentStatus.held.name)
        .orderBy('createdAt')
        .get();
    return [
      for (final doc in snapshot.docs)
        QueueItem(
          path: doc.reference.path,
          text: doc.data()['text'] as String? ?? '',
          createdAt: _date(doc.data()['createdAt']),
          holdReason: _reason(doc.data()['holdReason']),
          authorName: doc.data()['authorName'] as String?,
          authorUid: doc.data()['authorUid'] as String?,
          isReply: true,
          reportCount: (doc.data()['reportCount'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<List<Report>> openReports() async {
    final snapshot = await _db
        .collection('reports')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt')
        .get();
    return [
      for (final doc in snapshot.docs)
        Report(
          id: doc.id,
          reason: ReportReason.values.firstWhere(
            (r) => r.name == doc.data()['reason'],
            orElse: () => ReportReason.other,
          ),
          targetPath: doc.data()['targetPath'] as String? ?? '',
          targetText: doc.data()['targetText'] as String? ?? '',
          details: doc.data()['details'] as String? ?? '',
          createdAt: _date(doc.data()['createdAt']),
        ),
    ];
  }

  Future<void> _setStatus(String path, ContentStatus status) =>
      _db.doc(path).update({
        'status': status.name,
        'holdReason': status == ContentStatus.visible
            ? FieldValue.delete()
            : 'moderator',
      });

  @override
  Future<void> approve(QueueItem item) =>
      _setStatus(item.path, ContentStatus.visible);

  @override
  Future<void> remove(QueueItem item) =>
      _setStatus(item.path, ContentStatus.removed);

  @override
  Future<void> resolveReport(
    Report report, {
    required bool removeContent,
  }) async {
    final target = _db.doc(report.targetPath);
    await _db.runTransaction((tx) async {
      final data = (await tx.get(target)).data();
      tx.update(_db.collection('reports').doc(report.id), {
        'status': 'resolved',
        'action': removeContent ? 'removed' : 'kept',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (data == null) return;
      if (removeContent) {
        tx.update(target, {'status': ContentStatus.removed.name});
      } else if (data['status'] == ContentStatus.held.name &&
          data['holdReason'] == HoldReason.reports.name) {
        // Hidden only because of reports, and judged fine: restore it.
        tx.update(target, {
          'status': ContentStatus.visible.name,
          'holdReason': FieldValue.delete(),
        });
      }
    });
  }
}
