import '../models/account.dart';
import '../models/post.dart';
import '../models/sign_up_data.dart';

/// Posts, replies, reactions and journeys. Firestore in the app, in memory
/// in tests. Permission checks live in `firestore.rules`; the app mirrors
/// them with `FeedRules`.
abstract class FeedRepository {
  /// Newest posts in [topics], optionally only of one [type].
  Future<List<Post>> latest(
    Set<Topic> topics, {
    int limit = 30,
    PostType? type,
  });

  /// Unanswered questions in [topics], newest first.
  Future<List<Post>> needsAnswer(Set<Topic> topics, {int limit = 5});

  Future<Post?> getPost(String postId);

  /// Whether [viewer] wrote [post], including anonymous posts.
  Future<bool> isMine(Post post, Account viewer);

  Future<Post> createPost(Account author, NewPost draft);

  /// Visible replies, plus [viewer]'s own replies still waiting for a
  /// moderator.
  Future<List<Reply>> replies(String postId, {Account? viewer});

  /// [parent] makes it a reply to another reply (a nested thread).
  Future<Reply> addReply(
    Account author,
    Post post,
    String text, {
    Reply? parent,
  });

  /// Changes the text and tags of [author]'s own post. An edit that adds
  /// flagged words holds the post for a moderator again.
  Future<Post> editPost(
    Account author,
    Post post, {
    required String text,
    required List<String> tags,
  });

  /// Deletes [author]'s own post, its photos and videos, and its private
  /// author link.
  Future<void> deletePost(Account author, Post post);

  /// Visible posts with [tag], newest first.
  Future<List<Post>> withTag(String tag, {int limit = 30});

  /// Posts written in response to [postId], oldest first.
  Future<List<Post>> responsesTo(String postId);

  /// Everything [owner] posted, newest first, including anonymous posts
  /// (only ever shown to the owner).
  Future<List<Post>> postsBy(Account owner);

  /// Posts tagged into [journeyId], oldest first.
  Future<List<Post>> postsInJourney(String journeyId);

  Future<bool> hasBeenThere(String postId, Account viewer);

  Future<void> setBeenThere(Post post, Account viewer, bool on);

  /// IDs of the replies on [postId] that [viewer] marked Helpful.
  Future<Set<String>> myHelpful(
    String postId,
    List<Reply> replies,
    Account viewer,
  );

  Future<void> setHelpful(Reply reply, Account viewer, bool on);

  /// The asker marks [reply] as the one that helped; answers the question.
  Future<void> markHelpedAsker(Post post, Reply reply);

  Future<List<Journey>> myJourneys(Account owner);

  Future<Journey?> getJourney(String journeyId);

  /// The owner changes the story's title and intro.
  Future<Journey> updateJourney(
    Journey journey, {
    required String title,
    required String intro,
  });

  /// This week's Huddle question (the newest one), or null.
  Future<WeeklyPrompt?> currentPrompt();

  /// Moderators set a new weekly question.
  Future<WeeklyPrompt> createPrompt(Account moderator, String text);

  /// Visible posts answering [promptId], newest first.
  Future<List<Post>> answersTo(String promptId);

  Future<Journey> createJourney(Account owner, String title);

  /// Deletes everything [account] contributed (posts, replies, reactions,
  /// journeys, photos and videos). Part of account deletion.
  Future<void> deleteContributions(Account account);
}
