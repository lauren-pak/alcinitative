import 'dart:io';
import 'dart:typed_data';

import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/media.dart';
import 'package:athlete_app/models/moderation.dart';
import 'package:athlete_app/models/post.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/services/auth_service.dart';
import 'package:athlete_app/services/feed_repository.dart';
import 'package:athlete_app/services/media_repository.dart';
import 'package:athlete_app/services/profile_repository.dart';
import 'package:athlete_app/services/safety_repository.dart';

/// In-memory stand-in for Firebase Auth.
class FakeAuthService implements AuthService {
  static const validCode = '123456';

  final _emailAccounts = <String, ({String uid, String password})>{};
  final _phoneAccounts = <String, String>{};
  int _nextUid = 0;
  AuthUser? _current;

  /// What "Continue with Google" returns; null means Google isn't set up.
  AuthUser? googleUser;
  bool recentSignIn = true;
  int deletedUsers = 0;

  @override
  AuthUser? get currentUser => _current;

  @override
  bool get signedInRecently => recentSignIn;

  String _newUid() => 'uid${_nextUid++}';

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    if (_emailAccounts.containsKey(email)) {
      throw const AuthException(
        'This email already has an account. Log in instead.',
      );
    }
    final uid = _newUid();
    _emailAccounts[email] = (uid: uid, password: password);
    return _current = AuthUser(
      uid: uid,
      method: SignUpMethod.email,
      email: email,
    );
  }

  @override
  Future<AuthUser> logInWithEmail(String email, String password) async {
    final account = _emailAccounts[email];
    if (account == null || account.password != password) {
      throw const AuthException('Email or password is incorrect');
    }
    return _current = AuthUser(
      uid: account.uid,
      method: SignUpMethod.email,
      email: email,
    );
  }

  @override
  Future<String> sendPhoneCode(String phoneNumber) async => phoneNumber;

  @override
  Future<AuthUser> confirmPhoneCode(String verificationId, String code) async {
    if (code != validCode) {
      throw const AuthException("That code isn't right. Try again.");
    }
    final uid = _phoneAccounts.putIfAbsent(verificationId, _newUid);
    return _current = AuthUser(
      uid: uid,
      method: SignUpMethod.phone,
      phone: verificationId,
    );
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (googleUser == null) {
      throw const AuthException(
        "Google sign-in isn't set up for this app yet. "
        'Use your phone number or email for now.',
      );
    }
    return _current = googleUser;
  }

  @override
  Future<void> signOut() async => _current = null;

  @override
  Future<void> deleteCurrentUser() async {
    final uid = _current?.uid;
    _emailAccounts.removeWhere((_, a) => a.uid == uid);
    _phoneAccounts.removeWhere((_, u) => u == uid);
    _current = null;
    deletedUsers++;
  }
}

/// In-memory stand-in for Firestore. [findById] mirrors the under-18 rule in
/// `firestore.rules`, which is the real enforcement.
class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository(this._auth);

  final AuthService _auth;
  final accounts = <String, Account>{};

  @override
  Future<Account?> load(String uid) async => accounts[uid];

  @override
  Future<Account> create(String uid, SignUpData profile) async {
    String id;
    do {
      id = newAthleteId();
    } while (accounts.values.any((a) => a.athleteId == id));
    return accounts[uid] = Account(
      uid: uid,
      athleteId: id,
      profile: profile,
      joinedAt: DateTime.now(),
    );
  }

  @override
  Future<void> update(Account account) async => accounts[account.uid] = account;

  @override
  Future<Account?> findById(String athleteId) async {
    final now = DateTime.now();
    final viewer = accounts[_auth.currentUser?.uid];
    for (final a in accounts.values) {
      if (a.athleteId != athleteId) continue;
      final hidden =
          a.profile.isMinorOn(now) &&
          a != viewer &&
          !(viewer?.profile.isMinorOn(now) ?? false);
      return hidden ? null : a;
    }
    return null;
  }

  @override
  Future<List<Account>> searchByName(String query) async {
    final now = DateTime.now();
    final words = searchWords(query);
    if (words.isEmpty) return [];
    return [
      for (final a in accounts.values)
        if (a.profile.findable &&
            a.profile.canBeFindableOn(now) &&
            matchesName(a.profile.name, words))
          a,
    ].take(20).toList();
  }

  @override
  Future<List<Account>> browse({
    String? sport,
    AthleteCategory? category,
  }) async {
    final now = DateTime.now();
    return [
      for (final a in accounts.values)
        if (a.profile.findable &&
            a.profile.canBeFindableOn(now) &&
            (sport == null || a.profile.sport == sport) &&
            (category == null || a.profile.category == category))
          a,
    ]..sort((a, b) => a.profile.name.compareTo(b.profile.name));
  }

  @override
  Future<void> delete(Account account) async => accounts.remove(account.uid);
}

/// In-memory stand-in for the Firestore feed. Permission rules are tested
/// through `FeedRules`; `firestore.rules` is the real enforcement.
class InMemoryFeedRepository implements FeedRepository {
  final posts = <Post>[];
  final _authors = <String, String>{}; // postId -> uid
  final _replies = <String, List<Reply>>{};
  final _beenThere = <String, Set<String>>{};
  final _helpful = <String, Set<String>>{}; // replyId -> uids
  final journeys = <Journey>[];
  int _nextId = 0;

  String _id() => 'id${_nextId++}';

  void _replace(Post post) {
    final i = posts.indexWhere((p) => p.id == post.id);
    if (i >= 0) posts[i] = post;
  }

  Post _fresh(String id) => posts.firstWhere((p) => p.id == id);

  /// Feed queries only return visible posts, like the Firestore rules.
  Iterable<Post> get _visible =>
      posts.where((p) => p.status == ContentStatus.visible);

  List<Reply> allReplies(String postId) => _replies[postId] ??= [];

  /// Changes a post's or reply's status, as a moderator or reports would.
  void setStatus(String path, ContentStatus status, {int? reportCount}) {
    final parts = path.split('/');
    if (parts.length == 2) {
      _replace(
        _fresh(parts[1]).copyWith(status: status, reportCount: reportCount),
      );
    } else {
      final list = allReplies(parts[1]);
      final i = list.indexWhere((r) => r.id == parts[3]);
      list[i] = list[i].copyWith(status: status, reportCount: reportCount);
    }
  }

  @override
  Future<List<Post>> latest(Set<Topic> topics, {int limit = 30}) async =>
      (_visible.where((p) => topics.contains(p.topic)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(limit)
          .toList();

  @override
  Future<List<Post>> needsAnswer(Set<Topic> topics, {int limit = 5}) async =>
      (await latest(topics, limit: 1000))
          .where((p) => p.type == PostType.question && !p.answered)
          .take(limit)
          .toList();

  @override
  Future<Post?> getPost(String postId) async =>
      posts.where((p) => p.id == postId).firstOrNull;

  @override
  Future<bool> isMine(Post post, Account viewer) async =>
      _authors[post.id] == viewer.uid;

  @override
  Future<Post> createPost(Account author, NewPost draft) async {
    final hold = FeedRules.holdReasonFor(author, draft);
    final minor = FeedRules.isMinor(author);
    final post = Post(
      id: _id(),
      type: draft.type,
      topic: draft.topic!,
      text: draft.text.trim(),
      createdAt: DateTime.now(),
      author: draft.anonymous ? null : Author.of(author),
      authorRole: author.profile.role!,
      minorAuthor: FeedRules.isMinor(author),
      replyPolicy: draft.replyPolicy,
      journeyId: draft.anonymous ? null : draft.journey?.id,
      journeyTitle: draft.anonymous ? null : draft.journey?.title,
      media: draft.media,
      respondsToId: draft.respondingTo?.id,
      respondsToText: draft.respondingTo?.text,
      status: hold == null ? ContentStatus.visible : ContentStatus.held,
      holdReason: hold,
      adultRepliesAllowed: minor && draft.adultRepliesAllowed,
      tags: draft.tags,
    );
    posts.add(post);
    _authors[post.id] = author.uid;
    if (draft.respondingTo case final target?) {
      final fresh = _fresh(target.id);
      _replace(fresh.copyWith(responseCount: fresh.responseCount + 1));
    }
    return post;
  }

  @override
  Future<Post> editPost(Account author, Post post,
      {required String text, required List<String> tags}) async {
    if (_authors[post.id] != author.uid) throw StateError('permission-denied');
    final hold = FeedRules.editHoldReasonFor(_fresh(post.id), text, tags);
    final edited = _fresh(post.id).copyWith(
      text: text.trim(),
      tags: tags,
      editedAt: DateTime.now(),
      status: hold == null ? null : ContentStatus.held,
      holdReason: hold,
    );
    _replace(edited);
    return edited;
  }

  @override
  Future<void> deletePost(Account author, Post post) async {
    if (_authors[post.id] != author.uid) throw StateError('permission-denied');
    posts.removeWhere((p) => p.id == post.id);
    _authors.remove(post.id);
  }

  @override
  Future<List<Post>> withTag(String tag, {int limit = 30}) async =>
      (_visible.where((p) => p.tags.contains(tag)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(limit)
          .toList();

  @override
  Future<List<Post>> responsesTo(String postId) async =>
      _visible.where((p) => p.respondsToId == postId).toList();

  @override
  Future<List<Post>> postsBy(Account owner) async => [
    for (final p in posts.reversed)
      if (_authors[p.id] == owner.uid) p,
  ];

  @override
  Future<List<Post>> postsInJourney(String journeyId) async =>
      _visible.where((p) => p.journeyId == journeyId).toList();

  @override
  Future<List<Reply>> replies(String postId, {Account? viewer}) async => [
    for (final r in allReplies(postId))
      if (r.status == ContentStatus.visible ||
          (r.status == ContentStatus.held && r.author.uid == viewer?.uid))
        r,
  ];

  @override
  Future<Reply> addReply(
    Account author,
    Post post,
    String text, {
    Reply? parent,
  }) async {
    final hold = FeedRules.replyHoldReasonFor(author, post, text);
    final reply = Reply(
      id: _id(),
      postId: post.id,
      parentReplyId: parent?.id,
      author: Author.of(author),
      minorAuthor: FeedRules.isMinor(author),
      text: text.trim(),
      createdAt: DateTime.now(),
      status: hold == null ? ContentStatus.visible : ContentStatus.held,
      holdReason: hold,
    );
    (_replies[post.id] ??= []).add(reply);
    final fresh = _fresh(post.id);
    _replace(fresh.copyWith(replyCount: fresh.replyCount + 1));
    return reply;
  }

  @override
  Future<bool> hasBeenThere(String postId, Account viewer) async =>
      _beenThere[postId]?.contains(viewer.uid) ?? false;

  @override
  Future<void> setBeenThere(Post post, Account viewer, bool on) async {
    final set = _beenThere[post.id] ??= {};
    on ? set.add(viewer.uid) : set.remove(viewer.uid);
    _replace(_fresh(post.id).copyWith(beenThereCount: set.length));
  }

  @override
  Future<Set<String>> myHelpful(
    String postId,
    List<Reply> replies,
    Account viewer,
  ) async => {
    for (final r in replies)
      if (_helpful[r.id]?.contains(viewer.uid) ?? false) r.id,
  };

  @override
  Future<void> setHelpful(Reply reply, Account viewer, bool on) async {
    final set = _helpful[reply.id] ??= {};
    on ? set.add(viewer.uid) : set.remove(viewer.uid);
    final list = _replies[reply.postId]!;
    final i = list.indexWhere((r) => r.id == reply.id);
    list[i] = list[i].copyWith(helpfulCount: set.length);
  }

  @override
  Future<void> markHelpedAsker(Post post, Reply reply) async {
    final list = _replies[post.id]!;
    final i = list.indexWhere((r) => r.id == reply.id);
    list[i] = list[i].copyWith(helpedAsker: true);
    _replace(_fresh(post.id).copyWith(answered: true));
  }

  @override
  Future<List<Journey>> myJourneys(Account owner) async =>
      journeys.where((j) => j.ownerUid == owner.uid).toList();

  @override
  Future<Journey> createJourney(Account owner, String title) async {
    final journey = Journey(id: _id(), ownerUid: owner.uid, title: title);
    journeys.add(journey);
    return journey;
  }

  @override
  Future<void> deleteContributions(Account account) async {
    final uid = account.uid;
    final mine = {
      for (final e in _authors.entries)
        if (e.value == uid) e.key,
    };
    posts.removeWhere((p) => mine.contains(p.id));
    _authors.removeWhere((id, _) => mine.contains(id));
    for (final list in _replies.values) {
      list.removeWhere((r) => r.author.uid == uid);
    }
    for (final set in [..._beenThere.values, ..._helpful.values]) {
      set.remove(uid);
    }
    journeys.removeWhere((j) => j.ownerUid == uid);
  }
}

/// In-memory stand-in for Cloud Storage.
class FakeMediaRepository implements MediaRepository {
  final files = <String, Uint8List>{};
  int _next = 0;

  @override
  Future<MediaItem> uploadPhoto(Account owner, PreparedPhoto photo) async {
    final item = MediaItem(
      id: 'photo${_next++}',
      kind: MediaKind.photo,
      width: photo.width,
      height: photo.height,
    );
    files[item.path] = Uint8List.fromList(photo.jpeg);
    return item;
  }

  @override
  Future<MediaItem> uploadVideo(Account owner, PreparedVideo video) async {
    final item = MediaItem(
      id: 'video${_next++}',
      kind: MediaKind.video,
      width: video.width,
      height: video.height,
      durationMs: video.durationMs,
    );
    files[item.path] = Uint8List(0);
    return item;
  }

  @override
  Future<Uint8List> imageBytes(String path) async =>
      files[path] ?? (throw StateError('missing $path'));

  @override
  Future<File> videoFile(String path) async => throw UnimplementedError();
}

/// In-memory reporting and blocking, working on an [InMemoryFeedRepository].
class FakeSafetyRepository implements SafetyRepository {
  FakeSafetyRepository(this.feed);

  final InMemoryFeedRepository feed;
  final reports = <String, Report>{}; // reportId -> report
  final _reportCounts = <String, int>{}; // targetPath -> count
  final _blocked = <String, Map<String, String>>{}; // me -> uid -> name
  final moderators = <String>{};
  int _nextId = 0;

  bool _report(
    Account reporter,
    String path,
    String text,
    ReportReason reason,
    String details,
  ) {
    final id = reportId(path, reporter.uid);
    if (reports.containsKey(id)) return false;
    reports[id] = Report(
      id: 'r${_nextId++}',
      reason: reason,
      targetPath: path,
      targetText: text,
      details: details,
      createdAt: DateTime.now(),
    );
    final count = _reportCounts[path] = (_reportCounts[path] ?? 0) + 1;
    feed.setStatus(
      path,
      count >= reportsToHide ? ContentStatus.held : _statusOf(path),
      reportCount: count,
    );
    return true;
  }

  ContentStatus _statusOf(String path) {
    final parts = path.split('/');
    if (parts.length == 2) {
      return feed.posts.firstWhere((p) => p.id == parts[1]).status;
    }
    return feed.allReplies(parts[1]).firstWhere((r) => r.id == parts[3]).status;
  }

  @override
  Future<bool> reportPost(
    Account reporter,
    Post post,
    ReportReason reason, {
    String details = '',
  }) async => _report(reporter, 'posts/${post.id}', post.text, reason, details);

  @override
  Future<bool> reportReply(
    Account reporter,
    Reply reply,
    ReportReason reason, {
    String details = '',
  }) async => _report(
    reporter,
    'posts/${reply.postId}/replies/${reply.id}',
    reply.text,
    reason,
    details,
  );

  @override
  Future<Set<String>> blockedUids(Account me) async => {
    ...?_blocked[me.uid]?.keys,
  };

  @override
  Future<List<BlockedMember>> blockedMembers(Account me) async => [
    for (final e in (_blocked[me.uid] ?? const {}).entries)
      BlockedMember(uid: e.key, name: e.value),
  ];

  @override
  Future<void> block(Account me, Author other) async =>
      (_blocked[me.uid] ??= {})[other.uid] = other.name;

  @override
  Future<void> unblock(Account me, String uid) async =>
      _blocked[me.uid]?.remove(uid);

  @override
  Future<bool> isModerator(String uid) async => moderators.contains(uid);
}

/// In-memory moderation queue over the fake feed and reports.
class FakeModerationRepository implements ModerationRepository {
  FakeModerationRepository(this.feed, this.safety);

  final InMemoryFeedRepository feed;
  final FakeSafetyRepository safety;

  @override
  Future<List<QueueItem>> heldPosts() async => [
    for (final p in feed.posts)
      if (p.status == ContentStatus.held)
        QueueItem(
          path: 'posts/${p.id}',
          text: p.text,
          createdAt: p.createdAt,
          holdReason: p.holdReason,
          authorName: p.author?.name ?? 'Anonymous',
          reportCount: p.reportCount,
        ),
  ];

  @override
  Future<List<QueueItem>> heldReplies() async => [
    for (final p in feed.posts)
      for (final r in feed.allReplies(p.id))
        if (r.status == ContentStatus.held)
          QueueItem(
            path: 'posts/${p.id}/replies/${r.id}',
            text: r.text,
            createdAt: r.createdAt,
            holdReason: r.holdReason,
            authorName: r.author.name,
            authorUid: r.author.uid,
            isReply: true,
            reportCount: r.reportCount,
          ),
  ];

  final _resolved = <String>{};

  @override
  Future<List<Report>> openReports() async => [
    for (final r in safety.reports.values)
      if (!_resolved.contains(r.id)) r,
  ];

  @override
  Future<void> approve(QueueItem item) async =>
      feed.setStatus(item.path, ContentStatus.visible);

  @override
  Future<void> remove(QueueItem item) async =>
      feed.setStatus(item.path, ContentStatus.removed);

  @override
  Future<void> resolveReport(
    Report report, {
    required bool removeContent,
  }) async {
    _resolved.add(report.id);
    feed.setStatus(
      report.targetPath,
      removeContent ? ContentStatus.removed : ContentStatus.visible,
    );
  }
}
