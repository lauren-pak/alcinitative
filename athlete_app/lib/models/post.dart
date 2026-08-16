import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorSport;
  final String content;
  final DateTime createdAt;
  final int likeCount;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorSport,
    required this.content,
    required this.createdAt,
    required this.likeCount,
  });

  factory Post.fromMap(Map<String, dynamic> data, String id) {
    return Post(
      id: id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorSport: data['authorSport'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorSport': authorSport,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': likeCount,
    };
  }
}
