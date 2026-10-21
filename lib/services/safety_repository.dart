import '../models/account.dart';
import '../models/moderation.dart';
import '../models/post.dart';

/// A member someone has blocked.
class BlockedMember {
  const BlockedMember({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// Member safety tools: reporting and blocking. Muted topics live on the
/// profile (`SignUpData.mutedTopics`). Firestore in the app, in memory in
/// tests; `firestore.rules` enforces the counting and blocking.
abstract class SafetyRepository {
  /// Reports a post. Hides it for review once [reportsToHide] members have.
  /// Returns false if [reporter] already reported it.
  Future<bool> reportPost(Account reporter, Post post, ReportReason reason,
      {String details = ''});

  Future<bool> reportReply(Account reporter, Reply reply, ReportReason reason,
      {String details = ''});

  Future<Set<String>> blockedUids(Account me);

  Future<List<BlockedMember>> blockedMembers(Account me);

  Future<void> block(Account me, Author other);

  Future<void> unblock(Account me, String uid);

  /// Whether [uid] is listed in `moderators` (added in the Firebase console).
  Future<bool> isModerator(String uid);
}

/// Something waiting in the moderation queue.
class QueueItem {
  const QueueItem({
    required this.path,
    required this.text,
    required this.createdAt,
    this.holdReason,
    this.authorName,
    this.authorUid,
    this.isReply = false,
    this.reportCount = 0,
  });

  /// Firestore path of the post or reply.
  final String path;
  final String text;
  final DateTime createdAt;
  final HoldReason? holdReason;

  /// Shown to moderators even for anonymous posts.
  final String? authorName;
  final String? authorUid;
  final bool isReply;
  final int reportCount;
}

/// The moderator's queue and actions. Only works for accounts listed in
/// `moderators/{uid}`; the rules refuse everyone else.
abstract class ModerationRepository {
  Future<List<QueueItem>> heldPosts();

  Future<List<QueueItem>> heldReplies();

  Future<List<Report>> openReports();

  /// Puts a held (or reported) item back in the feed.
  Future<void> approve(QueueItem item);

  /// Takes it down; only moderators can still see it.
  Future<void> remove(QueueItem item);

  /// Closes a report, optionally removing what was reported.
  Future<void> resolveReport(Report report, {required bool removeContent});
}
