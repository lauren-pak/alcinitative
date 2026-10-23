import 'package:flutter/material.dart';

/// The app's look: energetic coral, deep navy and medal gold, with warm
/// gradients. Used by the theme in `main.dart` and by eye-catching pieces
/// like avatars, banners and badges.
class Brand {
  static const coral = Color(0xFFFF5A3C);
  static const navy = Color(0xFF14213D);
  static const gold = Color(0xFFFFB703);
  static const violet = Color(0xFF7B61FF);
  static const teal = Color(0xFF06A99B);
  static const cream = Color(0xFFFFF8F3);

  /// Coral into gold, like a sunrise over the track.
  static const sunrise = LinearGradient(
    colors: [coral, Color(0xFFFF8A3D), gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The ring around avatars: coral, gold and violet.
  static const ring = SweepGradient(colors: [coral, gold, violet, coral]);

  /// Navy into violet, for calmer banners.
  static const night = LinearGradient(
    colors: [navy, Color(0xFF3A2E8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Initials in a circle with a gradient ring, like a story ring.
class GradientAvatar extends StatelessWidget {
  const GradientAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.anonymous = false,
    this.verified = false,
  });

  final String name;
  final double radius;
  final bool anonymous;

  /// Adds a small ✓ badge for verified athletes.
  final bool verified;

  String get _initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = radius < 24 ? 2.0 : 3.5;
    final avatar = Container(
      padding: EdgeInsets.all(ring),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: Brand.ring,
      ),
      child: Container(
        padding: EdgeInsets.all(ring * 0.7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface,
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Brand.navy,
          child: anonymous || _initials.isEmpty
              ? Icon(
                  Icons.visibility_off_outlined,
                  size: radius,
                  color: Colors.white,
                )
              : Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: radius * 0.8,
                  ),
                ),
        ),
      ),
    );
    if (!verified) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: VerifiedBadge(size: radius * 0.7 < 16 ? 16 : radius * 0.7),
        ),
      ],
    );
  }
}

/// The blue-ish ✓ shown next to verified athletes.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified athlete',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Brand.teal,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.check, size: size * 0.65, color: Colors.white),
      ),
    );
  }
}

/// A rounded gradient banner with a title and a line of text.
class GradientBanner extends StatelessWidget {
  const GradientBanner({
    super.key,
    required this.title,
    required this.body,
    this.emoji,
    this.gradient = Brand.sunrise,
    this.action,
  });

  final String title;
  final String body;
  final String? emoji;
  final Gradient gradient;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
          if (emoji != null) ...[
            const SizedBox(width: 12),
            Text(emoji!, style: const TextStyle(fontSize: 40)),
          ],
        ],
      ),
    );
  }
}
