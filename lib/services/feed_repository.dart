import '../models/account.dart';
import '../models/post.dart';
import '../models/sign_up_data.dart';

/// Posts, replies, reactions and journeys. Firestore in the app, in memory
/// in tests. Permission checks live in `firestore.rules`; the app mirrors
/// them with `FeedRules`.
abstract class FeedRepository {
  /// Newest posts in [topics].
  Future<List<Post>> latest(Set<Topic> topics, {int limit = 30});

  /// Unanswered questions in [topics], newest first.
  Future<List<Post>> needsAnswer(Set<Topic> topics, {int limit = 5});

  Future<Post?> getPost(String postId);

  /// Whether [viewer] wrote [post], including anonymous posts.
  Future<bool> isMine(Post post, Account viewer);

  Future<Post> createPost(Account author, NewPost draft);

  Future<List<Reply>> replies(String postId);

  Future<Reply> addReply(Account author, Post post, String text);

  Future<bool> hasBeenThere(String postId, Account viewer);

  Future<void> setBeenThere(Post post, Account viewer, bool on);

  /// IDs of the replies on [postId] that [viewer] marked Helpful.
  Future<Set<String>> myHelpful(String postId, List<Reply> replies,
      Account viewer);

  Future<void> setHelpful(Reply reply, Account viewer, bool on);

  /// The asker marks [reply] as the one that helped; answers the question.
  Future<void> markHelpedAsker(Post post, Reply reply);

  Future<List<Journey>> myJourneys(Account owner);

  Future<Journey> createJourney(Account owner, String title);

  /// Deletes everything [account] contributed (posts, replies, reactions,
  /// journeys). Part of account deletion.
  Future<void> deleteContributions(Account account);
}
