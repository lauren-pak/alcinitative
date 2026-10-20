import 'auth_service.dart';
import 'profile_repository.dart';

/// Backend services. `main.dart` sets the Firebase ones; tests set fakes.
class Services {
  static late AuthService auth;
  static late ProfileRepository profiles;
}
