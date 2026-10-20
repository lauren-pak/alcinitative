import 'dart:math';

import 'sign_up_data.dart';

class Account {
  Account({
    required this.uid,
    required this.athleteId,
    required this.profile,
    required this.joinedAt,
  });

  /// Firebase Auth user ID.
  final String uid;

  /// Shown on the ID card, e.g. `AA-7KQ2MX`.
  final String athleteId;
  final SignUpData profile;
  final DateTime joinedAt;
}

// No 0/O or 1/I, so IDs are easy to read aloud and copy.
const _idChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
final _random = Random.secure();

/// A random athlete ID. Callers must check it isn't already taken.
String newAthleteId() {
  final code = List.generate(
    6,
    (_) => _idChars[_random.nextInt(_idChars.length)],
  ).join();
  return 'AA-$code';
}

/// Normalises what someone typed when looking up an ID: `aa-7kq2mx`,
/// `7KQ2MX` and `AA 7KQ2MX` all become `AA-7KQ2MX`.
String normaliseAthleteId(String input) {
  final code = input
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceFirst(RegExp('^AA'), '');
  return 'AA-$code';
}
