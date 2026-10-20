import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/account.dart';
import '../models/media.dart';
import '../models/post.dart';
import '../models/sign_up_data.dart';
import 'feed_repository.dart';

/// The feed in Cloud Firestore. See `docs/feed-design.md` for the data model
/// and `firestore.rules` for who may do what.
///
/// Every document a member creates is also listed under
/// `users/{uid}/contributions`, so deleting an account can find and delete
/// everything they wrote (PDPA: withdrawing consent).
class FirestoreFeedRepository implements FeedRepository {
  FirestoreFeedRepository({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');
  CollectionReference<Map<String, dynamic>> get _journeys =>
      _db.collection('journeys');
  DocumentReference<Map<String, dynamic>> _postAuthor(String postId) =>
      _db.collection('postAuthors').doc(postId);
  CollectionReference<Map<String, dynamic>> _contributions(String uid) =>
      _db.collection('users').doc(uid).collection('contributions');
  DocumentReference<Map<String, dynamic>> _beenThere(String postId, String uid) =>
      _posts.doc(postId).collection('beenThere').doc(uid);
  DocumentReference<Map<String, dynamic>> _helpful(Reply reply, String uid) =>
      _posts
          .doc(reply.postId)
          .collection('replies')
          .doc(reply.id)
          .collection('helpful')
          .doc(uid);

  void _record(WriteBatch batch, String uid, DocumentReference ref) =>
      batch.set(_contributions(uid).doc(), {'path': ref.path});

  @override
  Future<List<Post>> latest(Set<Topic> topics, {int limit = 30}) async {
    if (topics.isEmpty) return [];
    final snapshot = await _posts
        .where('topic', whereIn: [for (final t in topics) t.name])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final doc in snapshot.docs) _postFrom(doc.id, doc.data())];
  }

  @override
  Future<List<Post>> needsAnswer(Set<Topic> topics, {int limit = 5}) async {
    if (topics.isEmpty) return [];
    final snapshot = await _posts
        .where('type', isEqualTo: PostType.question.name)
        .where('answered', isEqualTo: false)
        .where('topic', whereIn: [for (final t in topics) t.name])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final doc in snapshot.docs) _postFrom(doc.id, doc.data())];
  }

  @override
  Future<Post?> getPost(String postId) async {
    final data = (await _posts.doc(postId).get()).data();
    return data == null ? null : _postFrom(postId, data);
  }

  @override
  Future<bool> isMine(Post post, Account viewer) async {
    if (!post.anonymous) return post.author!.uid == viewer.uid;
    try {
      // Only the author may read this link, so anyone else is denied.
      final link = await _postAuthor(post.id).get();
      return link.data()?['uid'] == viewer.uid;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  @override
  Future<Post> createPost(Account author, NewPost draft) async {
    final ref = _posts.doc();
    final journey = draft.anonymous ? null : draft.journey;
    final minor = FeedRules.isMinor(author);
    final target = draft.respondingTo;
    final preview = target == null ? null : _preview(target.text);
    final batch = _db.batch()
      ..set(ref, {
        'type': draft.type.name,
        'topic': draft.topic!.name,
        'text': draft.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'authorRole': author.profile.role!.name,
        'minorAuthor': minor,
        'replyPolicy': draft.replyPolicy.name,
        'anonymous': draft.anonymous,
        'answered': false,
        'replyCount': 0,
        'responseCount': 0,
        'beenThereCount': 0,
        'media': [for (final m in draft.media) m.toMap()],
        if (!draft.anonymous) ..._authorFields(Author.of(author)),
        if (journey != null) ...{
          'journeyId': journey.id,
          'journeyTitle': journey.title,
        },
        if (target != null) ...{
          'respondsToId': target.id,
          'respondsToText': preview,
        },
      })
      ..set(_postAuthor(ref.id), {'uid': author.uid});
    if (target != null) {
      // lastResponseId lets the rules check the count matches a real post.
      batch.update(_posts.doc(target.id), {
        'responseCount': FieldValue.increment(1),
        'lastResponseId': ref.id,
      });
    }
    _record(batch, author.uid, ref);
    _record(batch, author.uid, _postAuthor(ref.id));
    await batch.commit();
    return Post(
      id: ref.id,
      type: draft.type,
      topic: draft.topic!,
      text: draft.text.trim(),
      createdAt: DateTime.now(),
      author: draft.anonymous ? null : Author.of(author),
      authorRole: author.profile.role!,
      minorAuthor: minor,
      replyPolicy: draft.replyPolicy,
      journeyId: journey?.id,
      journeyTitle: journey?.title,
      media: draft.media,
      respondsToId: target?.id,
      respondsToText: preview,
    );
  }

  static String _preview(String text) => text.length <= respondsToPreviewLength
      ? text
      : '${text.substring(0, respondsToPreviewLength - 1)}…';

  @override
  Future<List<Post>> responsesTo(String postId) async {
    final snapshot = await _posts
        .where('respondsToId', isEqualTo: postId)
        .orderBy('createdAt')
        .get();
    return [for (final doc in snapshot.docs) _postFrom(doc.id, doc.data())];
  }

  @override
  Future<List<Post>> postsBy(Account owner) async {
    // The owner's private contribution list includes anonymous posts, which
    // can't be found any other way.
    final contributions = await _contributions(owner.uid).get();
    final ids = [
      for (final c in contributions.docs)
        if (_isPostPath(c.data()['path'] as String? ?? ''))
          (c.data()['path'] as String).split('/')[1],
    ];
    final docs = await Future.wait([for (final id in ids) _posts.doc(id).get()]);
    final posts = [
      for (final d in docs)
        if (d.data() case final data?) _postFrom(d.id, data),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  static bool _isPostPath(String path) {
    final parts = path.split('/');
    return parts.length == 2 && parts[0] == 'posts';
  }

  @override
  Future<List<Post>> postsInJourney(String journeyId) async {
    final snapshot = await _posts
        .where('journeyId', isEqualTo: journeyId)
        .orderBy('createdAt')
        .get();
    return [for (final doc in snapshot.docs) _postFrom(doc.id, doc.data())];
  }

  @override
  Future<List<Reply>> replies(String postId) async {
    final snapshot = await _posts
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt')
        .get();
    return [
      for (final doc in snapshot.docs) _replyFrom(postId, doc.id, doc.data()),
    ];
  }

  @override
  Future<Reply> addReply(Account author, Post post, String text,
      {Reply? parent}) async {
    final postRef = _posts.doc(post.id);
    final ref = postRef.collection('replies').doc();
    final minor = FeedRules.isMinor(author);
    final batch = _db.batch()
      ..set(ref, {
        ..._authorFields(Author.of(author)),
        if (parent != null) 'parentReplyId': parent.id,
        'authorRole': author.profile.role!.name,
        'minorAuthor': minor,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'helpfulCount': 0,
        'helpedAsker': false,
      })
      // lastReplyId lets the rules check the count matches a real new reply.
      ..update(postRef, {
        'replyCount': FieldValue.increment(1),
        'lastReplyId': ref.id,
      });
    _record(batch, author.uid, ref);
    await batch.commit();
    return Reply(
      id: ref.id,
      postId: post.id,
      parentReplyId: parent?.id,
      author: Author.of(author),
      minorAuthor: minor,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<bool> hasBeenThere(String postId, Account viewer) async =>
      (await _beenThere(postId, viewer.uid).get()).exists;

  @override
  Future<void> setBeenThere(Post post, Account viewer, bool on) async {
    final reaction = _beenThere(post.id, viewer.uid);
    final batch = _db.batch()
      ..update(_posts.doc(post.id), {
        'beenThereCount': FieldValue.increment(on ? 1 : -1),
      });
    if (on) {
      batch.set(reaction, {
        'uid': viewer.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _record(batch, viewer.uid, reaction);
    } else {
      batch.delete(reaction);
    }
    await batch.commit();
  }

  @override
  Future<Set<String>> myHelpful(
      String postId, List<Reply> replies, Account viewer) async {
    final marked = await Future.wait([
      for (final reply in replies)
        _helpful(reply, viewer.uid).get().then((s) => s.exists ? reply.id : null),
    ]);
    return marked.whereType<String>().toSet();
  }

  @override
  Future<void> setHelpful(Reply reply, Account viewer, bool on) async {
    final mark = _helpful(reply, viewer.uid);
    final batch = _db.batch()
      ..update(_posts.doc(reply.postId).collection('replies').doc(reply.id), {
        'helpfulCount': FieldValue.increment(on ? 1 : -1),
      });
    if (on) {
      batch.set(mark, {
        'uid': viewer.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _record(batch, viewer.uid, mark);
    } else {
      batch.delete(mark);
    }
    await batch.commit();
  }

  @override
  Future<void> markHelpedAsker(Post post, Reply reply) async {
    final batch = _db.batch()
      ..update(_posts.doc(post.id).collection('replies').doc(reply.id), {
        'helpedAsker': true,
      })
      ..update(_posts.doc(post.id), {'answered': true});
    await batch.commit();
  }

  @override
  Future<List<Journey>> myJourneys(Account owner) async {
    final snapshot = await _journeys
        .where('ownerUid', isEqualTo: owner.uid)
        .orderBy('createdAt', descending: true)
        .get();
    return [
      for (final doc in snapshot.docs)
        Journey(
          id: doc.id,
          ownerUid: owner.uid,
          title: doc.data()['title'] as String,
        ),
    ];
  }

  @override
  Future<Journey> createJourney(Account owner, String title) async {
    final ref = _journeys.doc();
    final batch = _db.batch()
      ..set(ref, {
        'ownerUid': owner.uid,
        'title': title.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    _record(batch, owner.uid, ref);
    await batch.commit();
    return Journey(id: ref.id, ownerUid: owner.uid, title: title.trim());
  }

  @override
  Future<void> deleteContributions(Account account) async {
    final contributions = await _contributions(account.uid).get();
    // Storage files first, and ownership links (author, media owner) last:
    // the rules check those links when deleting posts and files.
    int rank(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final path = d.data()['path'] as String;
      if (d.data()['storage'] == true) return 0;
      if (path.startsWith('postAuthors/') || path.startsWith('mediaOwners/')) {
        return 2;
      }
      return 1;
    }

    final docs = [...contributions.docs]
      ..sort((a, b) => rank(a) - rank(b));
    for (final c in docs.where((d) => rank(d) == 0)) {
      try {
        await _storage.ref(c.data()['path'] as String).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
      await c.reference.delete();
    }
    docs.removeWhere((d) => rank(d) == 0);
    // Firestore batches hold up to 500 writes; each item is two deletes.
    const chunk = 200;
    for (var i = 0; i < docs.length; i += chunk) {
      final batch = _db.batch();
      for (final c in docs.skip(i).take(chunk)) {
        batch
          ..delete(_db.doc(c.data()['path'] as String))
          ..delete(c.reference);
      }
      await batch.commit();
    }
  }

  static Map<String, Object?> _authorFields(Author a) => {
        'authorUid': a.uid,
        'authorName': a.name,
        'authorSport': a.sport,
        'authorLevel': a.level?.name,
        'authorCategory': a.category?.name,
      };

  static Author? _authorFrom(Map<String, dynamic> d) {
    final uid = d['authorUid'] as String?;
    if (uid == null) return null;
    return Author(
      uid: uid,
      name: d['authorName'] as String? ?? '',
      role: _enum(UserRole.values, d['authorRole']) ?? UserRole.athlete,
      sport: d['authorSport'] as String?,
      level: _enum(CompetitionLevel.values, d['authorLevel']),
      category: _enum(AthleteCategory.values, d['authorCategory']),
    );
  }

  static Post _postFrom(String id, Map<String, dynamic> d) => Post(
        id: id,
        type: _enum(PostType.values, d['type']) ?? PostType.experience,
        topic: _enum(Topic.values, d['topic']) ?? Topic.training,
        text: d['text'] as String? ?? '',
        createdAt: _date(d['createdAt']),
        author: d['anonymous'] == true ? null : _authorFrom(d),
        authorRole: _enum(UserRole.values, d['authorRole']) ?? UserRole.athlete,
        minorAuthor: d['minorAuthor'] as bool? ?? true,
        replyPolicy:
            _enum(ReplyPolicy.values, d['replyPolicy']) ?? ReplyPolicy.none,
        journeyId: d['journeyId'] as String?,
        journeyTitle: d['journeyTitle'] as String?,
        media: [
          for (final m in (d['media'] as List?) ?? const [])
            MediaItem.fromMap(Map<String, dynamic>.from(m as Map)),
        ],
        respondsToId: d['respondsToId'] as String?,
        respondsToText: d['respondsToText'] as String?,
        answered: d['answered'] as bool? ?? false,
        replyCount: (d['replyCount'] as num?)?.toInt() ?? 0,
        responseCount: (d['responseCount'] as num?)?.toInt() ?? 0,
        beenThereCount: (d['beenThereCount'] as num?)?.toInt() ?? 0,
      );

  static Reply _replyFrom(String postId, String id, Map<String, dynamic> d) =>
      Reply(
        id: id,
        postId: postId,
        parentReplyId: d['parentReplyId'] as String?,
        author: _authorFrom(d)!,
        minorAuthor: d['minorAuthor'] as bool? ?? true,
        text: d['text'] as String? ?? '',
        createdAt: _date(d['createdAt']),
        helpfulCount: (d['helpfulCount'] as num?)?.toInt() ?? 0,
        helpedAsker: d['helpedAsker'] as bool? ?? false,
      );

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static DateTime _date(Object? value) =>
      (value as Timestamp?)?.toDate() ?? DateTime.now();
}
