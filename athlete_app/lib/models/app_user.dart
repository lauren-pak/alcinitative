class AppUser {
  final String uid;
  final String name;
  final String sport;
  final String bio;
  final String email;

  AppUser({
    required this.uid,
    required this.name,
    required this.sport,
    required this.bio,
    required this.email,
  });

  // Convert a Firestore document into an AppUser object
  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      sport: data['sport'] ?? '',
      bio: data['bio'] ?? '',
      email: data['email'] ?? '',
    );
  }

  // Convert an AppUser object into a map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sport': sport,
      'bio': bio,
      'email': email,
    };
  }
}
