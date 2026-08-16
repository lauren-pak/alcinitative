import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/post.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isPosting = false;

  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    final user = FirebaseAuth.instance.currentUser!;
    final userProfile = await _firestoreService.getUser(user.uid);

    final newPost = Post(
      id: '', // Firestore generates this
      authorId: user.uid,
      authorName: userProfile?.name ?? 'Unknown Athlete',
      authorSport: userProfile?.sport ?? '',
      content: _contentController.text.trim(),
      createdAt: DateTime.now(),
      likeCount: 0,
    );

    await _firestoreService.createPost(newPost);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Advice')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Share training tips, advice, or a story with other athletes...',
              ),
            ),
            const SizedBox(height: 16),
            _isPosting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitPost,
                    child: const Text('Post'),
                  ),
          ],
        ),
      ),
    );
  }
}
