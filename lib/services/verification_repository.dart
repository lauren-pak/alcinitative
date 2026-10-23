import '../models/account.dart';
import '../models/sign_up_data.dart';

/// An athlete asking to be verified as a national, Paralympic or Special
/// Olympics athlete.
class VerificationRequest {
  const VerificationRequest({
    required this.uid,
    required this.athleteId,
    required this.name,
    required this.programme,
    required this.createdAt,
    this.sport,
    this.note = '',
  });

  final String uid;
  final String athleteId;
  final String name;
  final String? sport;
  final AthleteCategory programme;

  /// e.g. "Team Singapore swimming squad 2026", to help the reviewer check.
  final String note;
  final DateTime createdAt;
}

/// Athlete verification (step 3 in `docs/events.md`). Athletes ask; a
/// moderator or organiser checks (with the sports association or SOSG)
/// and approves. Verified athletes get a ✓, and only they can share
/// spotlights and answer "Ask an athlete" questions (enforced by
/// `firestore.rules`).
abstract class VerificationRepository {
  Future<bool> isVerified(String uid);

  Future<VerificationRequest?> myRequest(Account me);

  Future<void> requestVerification(
    Account me,
    AthleteCategory programme, {
    String note = '',
  });

  Future<void> withdrawRequest(Account me);

  /// Moderators and organisers can verify.
  Future<bool> canVerify(String uid);

  Future<List<VerificationRequest>> pendingRequests();

  Future<void> approve(VerificationRequest request, Account reviewer);

  Future<void> decline(VerificationRequest request);
}
