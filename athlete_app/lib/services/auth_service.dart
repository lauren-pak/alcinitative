import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream that tells the app whether someone is logged in
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Create a new account AND a matching user document in Firestore
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String sport,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUser = AppUser(
        uid: credential.user!.uid,
        name: name,
        sport: sport,
        bio: '',
        email: email,
      );

      // Save the extra profile info in the "users" collection
      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());

      return null; // null means "no error"
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed';
    }
  }

  Future<String?> logIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    }
  }

  Future<void> logOut() async {
    await _auth.signOut();
  }
}
