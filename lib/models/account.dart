import 'dart:math';

import 'sign_up_data.dart';

class Account {
  Account({
    required this.uid,
    required this.athleteId,
    required this.profile,
    required this.joinedAt,
    this.verified = false,
  });

  /// Firebase Auth user ID.
  final String uid;

  /// Shown on the ID card, e.g. `AA-7KQ2MX`.
  final String athleteId;
  final SignUpData profile;
  final DateTime joinedAt;

  /// Verified by a moderator or organiser as a national, Paralympic or
  /// Special Olympics athlete (`verifiedAthletes/{uid}`). Only verified
  /// athletes share spotlights and answer "Ask an athlete" questions.
  bool verified;
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

/// Lowercase words of a name or search, e.g. "Sam Taylor" → [sam, taylor].
List<String> searchWords(String text) => [
  for (final w in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (w.isNotEmpty) w,
];

/// Every prefix of every word in [name] (from 1 letter, up to 15), so a
/// search for "tay" finds "Sam Taylor". Stored on findable ID cards only.
List<String> nameSearchKeys(String name) => {
  for (final w in searchWords(name))
    for (var i = 1; i <= w.length && i <= 15; i++) w.substring(0, i),
}.take(60).toList();

/// Whether every search word starts one of the name's words.
bool matchesName(String name, List<String> searchWordList) {
  final words = searchWords(name);
  return searchWordList.every(
    (s) =>
        words.any((w) => w.startsWith(s.length > 15 ? s.substring(0, 15) : s)),
  );
}
