import 'account.dart';
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
    this.answered = false,
    this.replyCount = 0,
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

  /// A question whose asker marked a reply "This helped me".
  final bool answered;
  final int replyCount;
  final int beenThereCount;

  bool get anonymous => author == null;

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
    bool? answered,
    int? replyCount,
    int? beenThereCount,
  }) =>
      Post(
        id: id,
        type: type,
        topic: topic,
        text: text,
        createdAt: createdAt,
        author: author,
        authorRole: authorRole,
        minorAuthor: minorAuthor,
        replyPolicy: replyPolicy,
        journeyId: journeyId,
        journeyTitle: journeyTitle,
        answered: answered ?? this.answered,
        replyCount: replyCount ?? this.replyCount,
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
    this.helpfulCount = 0,
    this.helpedAsker = false,
  });

  final String id;
  final String postId;
  final Author author;
  final bool minorAuthor;
  final String text;
  final DateTime createdAt;
  final int helpfulCount;

  /// The asker marked this reply "This helped me".
  final bool helpedAsker;

  Reply copyWith({int? helpfulCount, bool? helpedAsker}) => Reply(
        id: id,
        postId: postId,
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
}

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

  /// Under-18 nutrition posts need moderator review, which arrives in
  /// stage 2 of the feed. Until then they can't be posted.
  static String? topicBlockedFor(Account a, Topic topic) =>
      topic == Topic.nutrition && isMinor(a)
          ? 'Sports nutrition posts from under-18s are checked by a '
              "moderator first. That's coming soon."
          : null;

  /// Null if [viewer] may reply to [post].
  static String? replyBlockedFor(Account viewer, Post post) {
    if (post.replyPolicy == ReplyPolicy.none) return 'Replies are turned off.';
    if (post.replyPolicy == ReplyPolicy.athletes &&
        viewer.profile.role != UserRole.athlete) {
      return 'Only athletes can reply to this post.';
    }
    // Adult replies to under-18s will need moderator review (stage 2).
    if (post.minorAuthor && !isMinor(viewer)) {
      return 'Only under-18s can reply to this post.';
    }
    return null;
  }
}
