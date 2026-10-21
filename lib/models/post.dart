import 'account.dart';
import 'media.dart';
import 'moderation.dart';
import 'sign_up_data.dart';

enum PostType {
  experience('Experience'),
  question('Question');

  const PostType(this.label);
  final String label;
}

/// Who may reply to a post, chosen by the poster.
enum ReplyPolicy {
  athletes('Athletes'),
  everyone('Everyone'),
  none('No replies');

  const ReplyPolicy(this.label);
  final String label;
}

/// The public face of whoever wrote a post or reply. Null fields for
/// anonymous posts.
class Author {
  const Author({
    required this.uid,
    required this.name,
    required this.role,
    this.sport,
    this.level,
    this.category,
  });

  /// From an account, using only ID-card fields (never date of birth).
  factory Author.of(Account account) {
    final p = account.profile;
    return Author(
      uid: account.uid,
      name: p.name,
      role: p.role!,
      sport: p.role == UserRole.athlete ? p.sportName : null,
      level: p.level,
      category: p.category,
    );
  }

  final String uid;
  final String name;
  final UserRole role;
  final String? sport;
  final CompetitionLevel? level;
  final AthleteCategory? category;

  /// e.g. "Swimming · Club" or "General public".
  String get subtitle => role == UserRole.athlete && sport != null
      ? '$sport${level == null ? '' : ' · ${level!.label}'}'
      : role.label;
}

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.topic,
    required this.text,
    required this.createdAt,
    required this.authorRole,
    required this.minorAuthor,
    required this.replyPolicy,
    this.author,
    this.journeyId,
    this.journeyTitle,
    this.media = const [],
    this.respondsToId,
    this.respondsToText,
    this.status = ContentStatus.visible,
    this.holdReason,
    this.reportCount = 0,
    this.adultRepliesAllowed = false,
    this.tags = const [],
    this.editedAt,
    this.answered = false,
    this.replyCount = 0,
    this.responseCount = 0,
    this.beenThereCount = 0,
  });

  final String id;
  final PostType type;
  final Topic topic;
  final String text;
  final DateTime createdAt;

  /// Null when posted anonymously.
  final Author? author;
  final UserRole authorRole;

  /// Under 18 when they posted. Fixed for the life of the post.
  final bool minorAuthor;
  final ReplyPolicy replyPolicy;
  final String? journeyId;
  final String? journeyTitle;

  /// Up to 4 photos, or 1 video.
  final List<MediaItem> media;

  /// Set when this post responds to another post; it then also appears in
  /// that post's comments.
  final String? respondsToId;

  /// The start of the post this responds to, for the "In response to" line.
  final String? respondsToText;

  final ContentStatus status;
  final HoldReason? holdReason;
  final int reportCount;

  /// An under-18 poster's choice to let adults reply. Each adult reply is
  /// held for a moderator.
  final bool adultRepliesAllowed;

  bool get isHeld => status == ContentStatus.held;

  /// Lowercase search tags, e.g. "acl" (see [normaliseTag]).
  final List<String> tags;

  /// When the author last edited the text or tags; null if never.
  final DateTime? editedAt;

  /// A question whose asker marked a reply "This helped me".
  final bool answered;
  final int replyCount;

  /// Posts written in response to this one.
  final int responseCount;
  final int beenThereCount;

  bool get anonymous => author == null;

  /// Replies plus response posts.
  int get commentCount => replyCount + responseCount;

  /// Label for the post's author line.
  String get authorName => author?.name ?? 'Anonymous ${_roleNoun()}';

  String _roleNoun() =>
      authorRole == UserRole.athlete ? 'athlete' : 'member';

  /// Questions from general public members are labelled as such.
  String get typeLabel => type == PostType.question &&
          authorRole == UserRole.public
      ? 'Question from the public'
      : type.label;

  /// Injury and nutrition posts carry a "not medical advice" banner.
  bool get needsAdviceBanner =>
      topic == Topic.injury || topic == Topic.nutrition;

  Post copyWith({
    String? text,
    List<String>? tags,
    DateTime? editedAt,
    HoldReason? holdReason,
    bool? answered,
    int? replyCount,
    int? responseCount,
    int? beenThereCount,
    ContentStatus? status,
    int? reportCount,
  }) =>
      Post(
        id: id,
        type: type,
        topic: topic,
        text: text ?? this.text,
        createdAt: createdAt,
        author: author,
        authorRole: authorRole,
        minorAuthor: minorAuthor,
        replyPolicy: replyPolicy,
        journeyId: journeyId,
        journeyTitle: journeyTitle,
        media: media,
        respondsToId: respondsToId,
        respondsToText: respondsToText,
        status: status ?? this.status,
        holdReason: holdReason ?? this.holdReason,
        reportCount: reportCount ?? this.reportCount,
        adultRepliesAllowed: adultRepliesAllowed,
        tags: tags ?? this.tags,
        editedAt: editedAt ?? this.editedAt,
        answered: answered ?? this.answered,
        replyCount: replyCount ?? this.replyCount,
        responseCount: responseCount ?? this.responseCount,
        beenThereCount: beenThereCount ?? this.beenThereCount,
      );
}

class Reply {
  const Reply({
    required this.id,
    required this.postId,
    required this.author,
    required this.minorAuthor,
    required this.text,
    required this.createdAt,
    this.parentReplyId,
    this.helpfulCount = 0,
    this.helpedAsker = false,
    this.status = ContentStatus.visible,
    this.holdReason,
    this.reportCount = 0,
  });

  final String id;
  final String postId;

  /// The reply this one answers; null for a reply to the post itself.
  final String? parentReplyId;
  final Author author;
  final bool minorAuthor;
  final String text;
  final DateTime createdAt;
  final int helpfulCount;

  /// The asker marked this reply "This helped me".
  final bool helpedAsker;

  final ContentStatus status;
  final HoldReason? holdReason;
  final int reportCount;

  bool get isHeld => status == ContentStatus.held;

  Reply copyWith({
    int? helpfulCount,
    bool? helpedAsker,
    ContentStatus? status,
    int? reportCount,
  }) =>
      Reply(
        id: id,
        postId: postId,
        parentReplyId: parentReplyId,
        status: status ?? this.status,
        holdReason: holdReason,
        reportCount: reportCount ?? this.reportCount,
        author: author,
        minorAuthor: minorAuthor,
        text: text,
        createdAt: createdAt,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        helpedAsker: helpedAsker ?? this.helpedAsker,
      );
}

/// A named playlist of someone's posts, e.g. "ACL rehab 2026".
class Journey {
  const Journey({required this.id, required this.ownerUid, required this.title});

  final String id;
  final String ownerUid;
  final String title;
}

/// What a member is writing in the composer.
class NewPost {
  PostType type = PostType.experience;
  Topic? topic;
  String text = '';
  ReplyPolicy replyPolicy = ReplyPolicy.athletes;
  bool anonymous = false;
  Journey? journey;

  /// Uploaded before the post is saved.
  List<MediaItem> media = [];

  /// The post this one responds to, if any.
  Post? respondingTo;

  /// Under-18s only: let adults reply (each reply is reviewed first).
  bool adultRepliesAllowed = false;

  /// Search tags, already normalised (see [normaliseTag]).
  List<String> tags = [];
}

/// Most tags a post can have.
const maxTags = 5;

/// Turns what someone typed into a tag: lowercase letters and numbers only,
/// 2 to 20 long, without the "#". Returns null if nothing usable is left.
/// `firestore.rules` checks the same format.
String? normaliseTag(String input) {
  final tag = input.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  if (tag.length < 2) return null;
  return tag.length > 20 ? tag.substring(0, 20) : tag;
}

/// Length of the quote shown in "In response to".
const respondsToPreviewLength = 120;

const maxPostLength = 2000;
const maxReplyLength = 1000;

/// Feed rules shared by the app and mirrored in `firestore.rules`.
/// Each returns null if allowed, or the reason it isn't.
class FeedRules {
  static bool isMinor(Account a) => a.profile.isMinorOn(DateTime.now());

  /// General public members can only ask questions.
  static List<PostType> postTypesFor(Account a) =>
      a.profile.role == UserRole.public
          ? const [PostType.question]
          : PostType.values;

  /// Shown when a choice means the post waits for a moderator.
  static String? topicReviewNoteFor(Account a, Topic topic) =>
      topic == Topic.nutrition && isMinor(a)
          ? 'Sports nutrition posts from under-18s are checked by a '
              'moderator before others can see them.'
          : null;

  /// Why [draft] would wait for a moderator, or null if it goes straight
  /// into the feed. Mirrors `postHoldReason` in `firestore.rules`.
  static HoldReason? holdReasonFor(Account a, NewPost draft) {
    if (flagged(draft.text, draft.tags)) return HoldReason.flaggedWords;
    if (!isMinor(a)) {
      return draft.respondingTo?.minorAuthor ?? false
          ? HoldReason.adultReplyToMinor
          : null;
    }
    if (draft.topic == Topic.nutrition) return HoldReason.minorNutrition;
    if (draft.media.any((m) => m.kind == MediaKind.video)) {
      return HoldReason.minorVideo;
    }
    return null;
  }

  /// Flagged words in a post's text or tags.
  static bool flagged(String text, List<String> tags) =>
      containsFlaggedWords([text, ...tags].join(' '));

  /// An edit that adds flagged words sends a visible post back for review.
  /// Held and removed posts stay as they are.
  static HoldReason? editHoldReasonFor(
          Post post, String text, List<String> tags) =>
      post.status == ContentStatus.visible && flagged(text, tags)
          ? HoldReason.flaggedWords
          : null;

  /// Why a reply would wait for a moderator. Mirrors `firestore.rules`.
  static HoldReason? replyHoldReasonFor(Account viewer, Post post, String text) {
    if (containsFlaggedWords(text)) return HoldReason.flaggedWords;
    if (post.minorAuthor && !isMinor(viewer)) {
      return HoldReason.adultReplyToMinor;
    }
    return null;
  }

  /// Under-18 videos are checked by a person before going live.
  static String? videoReviewNoteFor(Account a) => isMinor(a)
      ? 'Videos from under-18s are checked by a moderator before others '
          'can see them.'
      : null;

  /// Null if [viewer] may reply to [post], or to [parent] within it.
  /// Response posts follow the same rules as replies.
  static String? replyBlockedFor(Account viewer, Post post, {Reply? parent}) {
    if (post.replyPolicy == ReplyPolicy.none) return 'Replies are turned off.';
    if (post.replyPolicy == ReplyPolicy.athletes &&
        viewer.profile.role != UserRole.athlete) {
      return 'Only athletes can reply to this post.';
    }
    // Adults can reply to an under-18 only if they allowed it; each such
    // reply waits for a moderator.
    if (post.minorAuthor && !isMinor(viewer) && !post.adultRepliesAllowed) {
      return 'Only under-18s can reply to this post.';
    }
    if (parent != null && parent.minorAuthor && !isMinor(viewer)) {
      return 'Only under-18s can reply to this reply.';
    }
    return null;
  }
}
