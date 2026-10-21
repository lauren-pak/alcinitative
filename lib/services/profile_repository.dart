import '../models/account.dart';
import '../models/sign_up_data.dart';

/// Stores member profiles. Firestore in the app, in memory in tests.
abstract class ProfileRepository {
  /// The signed-in member's own profile, or null if they haven't finished
  /// signing up.
  Future<Account?> load(String uid);

  /// Saves a new profile with a fresh, unique athlete ID.
  Future<Account> create(String uid, SignUpData profile);

  /// Saves edits to name, sport, level, programme and topics. Date of birth
  /// can't be changed in the app because it controls under-18 protections.
  Future<void> update(Account account);

  /// Looks up a shared athlete ID. Returns null if it doesn't exist or the
  /// viewer isn't allowed to see it (adults can't see under-18s).
  Future<Account?> findById(String athleteId);

  /// Athletes who opted in to name search ([SignUpData.findable]) whose
  /// first or last name starts with the words in [query]. Up to 20.
  Future<List<Account>> searchByName(String query);

  /// Findable athletes ([SignUpData.findable]) in [sport] and/or
  /// [category] (either may be null for "any"), by name. Up to 50.
  Future<List<Account>> browse({String? sport, AthleteCategory? category});

  /// Deletes the member's profile and athlete ID card.
  Future<void> delete(Account account);
}
