import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import '../models/app_user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Live stream of all posts, newest first — this powers the home feed
  Stream<List<Post>> getPostsStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Post.fromMap(doc.data(), doc.id)).toList());
  }

  // Create a new post
  Future<void> createPost(Post post) async {
    await _db.collection('posts').add(post.toMap());
  }

  // Simple like counter increment
  Future<void> likePost(String postId) async {
    await _db.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(1),
    });
  }

  // Fetch a single user's profile
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  // Update bio / sport on the profile screen
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }
}
