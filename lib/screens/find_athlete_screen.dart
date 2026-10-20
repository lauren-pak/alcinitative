import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/services.dart';
import '../widgets/athlete_id_card.dart';

/// Look up another athlete by the ID they shared.
/// Who can be found is decided by the server (`firestore.rules`): adults
/// can't see under-18s, and get the same "not found" as for a missing ID.
class FindAthleteScreen extends StatefulWidget {
  const FindAthleteScreen({super.key});

  @override
  State<FindAthleteScreen> createState() => _FindAthleteScreenState();
}

class _FindAthleteScreenState extends State<FindAthleteScreen> {
  final _input = TextEditingController();
  Account? _result;
  bool _searched = false;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    if (_input.text.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result =
          await Services.profiles.findById(normaliseAthleteId(_input.text));
      if (!mounted) return;
      setState(() {
        _result = result;
        _searched = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't search. Check your connection.");
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Find an athlete')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the ID another athlete shared with you.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _input,
                  decoration: const InputDecoration(
                    labelText: 'Athlete ID',
                    hintText: 'AA-7KQ2MX',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: const Text('Find'),
                ),
                const SizedBox(height: 24),
                if (_searching)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: textTheme.bodyLarge)
                else if (_result != null)
                  AthleteIdCard(account: _result!)
                else if (_searched)
                  Text(
                    'No athlete found with that ID. Check it and try again.',
                    style: textTheme.bodyLarge,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
