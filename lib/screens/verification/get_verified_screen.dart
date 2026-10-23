import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../../services/verification_repository.dart';
import '../../widgets/brand.dart';

/// Athletes ask to be verified as a national, Paralympic or Special
/// Olympics athlete. A moderator or organiser checks and approves.
class GetVerifiedScreen extends StatefulWidget {
  const GetVerifiedScreen({super.key, required this.account});

  final Account account;

  @override
  State<GetVerifiedScreen> createState() => _GetVerifiedScreenState();
}

class _GetVerifiedScreenState extends State<GetVerifiedScreen> {
  late Future<VerificationRequest?> _request = Services.verification.myRequest(
    widget.account,
  );
  late AthleteCategory? _programme = widget.account.profile.category;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await Services.verification.requestVerification(
        widget.account,
        _programme!,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _request = Services.verification.myRequest(widget.account);
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send. Check your connection and try again."),
        ),
      );
    }
  }

  Future<void> _withdraw() async {
    await Services.verification.withdrawRequest(widget.account);
    if (mounted) {
      setState(() {
        _request = Services.verification.myRequest(widget.account);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Get verified')),
      body: FutureBuilder<VerificationRequest?>(
        future: _request,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final pending = snapshot.data;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const GradientBanner(
                title: 'Get your ✓',
                body:
                    'Verified national, Paralympic and Special Olympics '
                    'athletes share spotlights and answer questions in '
                    'Huddle.',
                emoji: '🏅',
                gradient: Brand.night,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: widget.account.verified
                    ? Row(
                        children: [
                          const VerifiedBadge(size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "You're verified!",
                              style: textTheme.titleLarge,
                            ),
                          ),
                        ],
                      )
                    : pending != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Request sent ⏳', style: textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'A moderator will check that you are a '
                            '${pending.programme.label.toLowerCase()}. '
                            'This can take a few days.',
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _withdraw,
                            child: const Text('Cancel my request'),
                          ),
                        ],
                      )
                    : _form(textTheme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _form(TextTheme textTheme) {
    if (widget.account.profile.role != UserRole.athlete) {
      return Text(
        'Verification is for athletes. You can still ask athletes questions '
        'and join events.',
        style: textTheme.bodyLarge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Which programme are you in?', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<AthleteCategory>(
          groupValue: _programme,
          onChanged: (v) => setState(() => _programme = v),
          child: Column(
            children: [
              for (final c in AthleteCategory.values)
                RadioListTile<AthleteCategory>(
                  contentPadding: EdgeInsets.zero,
                  value: c,
                  title: Text(c.label),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Anything that helps us check (optional)',
            hintText: 'e.g. Team Singapore swimming squad, SOSG bocce',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _programme == null || _sending ? null : _send,
          child: const Text('Ask to be verified'),
        ),
      ],
    );
  }
}
