import 'auth_service.dart';
import 'feed_repository.dart';
import 'media_repository.dart';
import 'profile_repository.dart';
import 'safety_repository.dart';

/// Backend services. `main.dart` sets the Firebase ones; tests set fakes.
class Services {
  static late AuthService auth;
  static late ProfileRepository profiles;
  static late FeedRepository feed;
  static late MediaRepository media;
  static late SafetyRepository safety;
  static late ModerationRepository moderation;
}
