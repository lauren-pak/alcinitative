import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../services/services.dart';
import '../../services/verification_repository.dart';
import '../../widgets/brand.dart';

/// Moderators and organisers check verification requests. Check with the
/// sports association or SOSG before approving.
class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({super.key, required this.reviewer});

  final Account reviewer;

  @override
  State<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  late Future<List<VerificationRequest>> _requests = Services.verification
      .pendingRequests();

  Future<void> _refresh() async {
    final next = Services.verification.pendingRequests();
    setState(() {
      _requests = next;
    });
    await next.catchError((_) => <VerificationRequest>[]);
  }

  Future<void> _act(VerificationRequest r, bool approve) async {
    try {
      approve
          ? await Services.verification.approve(r, widget.reviewer)
          : await Services.verification.decline(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? '${r.name} is verified ✓' : 'Declined.'),
        ),
      );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify athletes')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<VerificationRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data ?? const <VerificationRequest>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Check each athlete with their sports association or SOSG '
                  'before approving.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No requests waiting. 🎉',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final r in requests)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GradientAvatar(name: r.name, radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name, style: textTheme.titleMedium),
                                    Text(
                                      [r.athleteId, ?r.sport].join(' · '),
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Says they are: ${r.programme.label}',
                            style: textTheme.bodyLarge,
                          ),
                          if (r.note.isNotEmpty)
                            Text('“${r.note}”', style: textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _act(r, false),
                                child: const Text('Decline'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _act(r, true),
                                icon: const Icon(Icons.verified),
                                label: const Text('Verify'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
