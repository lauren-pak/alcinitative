/// Stage 2 safety: review statuses, reports and the flagged-word check.
/// See docs/feed-design.md ("Safety") and the moderation section of
/// `firestore.rules`, which enforces the same rules on the server.
library;

/// Whether a post or reply can be seen by members.
enum ContentStatus {
  /// In the feed for everyone.
  visible,

  /// Waiting for a moderator. Only the author and moderators can see it.
  held,

  /// Taken down by a moderator. Only moderators can see it.
  removed,
}

/// Why something is waiting for a moderator.
enum HoldReason {
  flaggedWords('Sensitive words'),
  minorNutrition('Under-18 nutrition post'),
  minorVideo('Under-18 video'),
  adultReplyToMinor('Adult reply to an under-18'),
  reports('Reported by members'),
  newQuestion('New "Ask an athlete" question');

  const HoldReason(this.label);
  final String label;
}

/// A post or reply is hidden for review after this many members report it.
const reportsToHide = 3;

enum ReportReason {
  bullying('Bullying or unkind'),
  unsafeAdvice('Unsafe advice'),
  inappropriate('Inappropriate or sexual'),
  wellbeing('Self-harm or eating worries'),
  spam('Spam or fake'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

/// Words that suggest someone may be struggling, or giving dangerous
/// advice, especially around eating, weight and self-harm. Posts containing
/// them show the writer support links and wait for a moderator.
///
/// **Must stay identical** to the pattern in `flagged()` in `firestore.rules`
/// (RE2).
const flaggedWordsPattern =
    r'(?s).*('
    r'purg|starv|laxative|diet pill|skip(ping)? meals|not eating|stop(ped)? eating|'
    r'throw(ing)? up|make myself sick|cut(ting)? weight fast|weight cut|'
    r'self.?harm|cutting myself|hurt myself|kill myself|suicid|want to die|end it all'
    r').*';

// Dart has no inline (?s) flag, so drop it and use dotAll (same meaning).
final _flagged = RegExp(
  flaggedWordsPattern.replaceFirst('(?s)', ''),
  dotAll: true,
);

bool containsFlaggedWords(String text) => _flagged.hasMatch(text.toLowerCase());

/// A member's report of a post or reply. One per member per item.
class Report {
  const Report({
    required this.id,
    required this.reason,
    required this.targetPath,
    required this.targetText,
    required this.createdAt,
    this.details = '',
  });

  final String id;
  final ReportReason reason;

  /// Firestore path of the reported post or reply.
  final String targetPath;

  /// A copy of what was reported, so moderators see it even if edited.
  final String targetText;
  final String details;
  final DateTime createdAt;

  bool get isReply => targetPath.contains('/replies/');
}

/// Deterministic report ID, so each member can report an item only once.
String reportId(String targetPath, String reporterUid) =>
    '${targetPath.replaceAll('/', '_')}__$reporterUid';
