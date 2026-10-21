import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/sign_up_data.dart';
import '../services/services.dart';
import '../widgets/athlete_id_card.dart';

/// Browse athletes by sport and programme, search by name, or look up the
/// ID someone shared. Who can be found is decided by the server
/// (`firestore.rules`):
/// - Browse and name: only adult athletes with "Show me in Find athlete"
///   on (the default for them). Under-18s never show up.
/// - By ID: adults can't see under-18s, and get the same "not found" as for
///   a missing ID.
class FindAthleteScreen extends StatefulWidget {
  const FindAthleteScreen({super.key});

  @override
  State<FindAthleteScreen> createState() => _FindAthleteScreenState();
}

enum _By { browse, name, id }

class _FindAthleteScreenState extends State<FindAthleteScreen> {
  final _input = TextEditingController();
  _By _by = _By.browse;
  String? _sport;
  AthleteCategory? _category;
  Account? _result;
  List<Account> _matches = const [];
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
    if (_by != _By.browse && _input.text.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      if (_by == _By.id) {
        final result = await Services.profiles.findById(
          normaliseAthleteId(_input.text),
        );
        if (!mounted) return;
        setState(() {
          _result = result;
          _searched = true;
        });
      } else {
        final matches = _by == _By.browse
            ? await Services.profiles.browse(sport: _sport, category: _category)
            : await Services.profiles.searchByName(_input.text);
        if (!mounted) return;
        setState(() {
          _matches = matches;
          _searched = true;
        });
      }
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
                SegmentedButton<_By>(
                  segments: const [
                    ButtonSegment(
                      value: _By.browse,
                      icon: Icon(Icons.groups_outlined),
                      label: Text('Browse'),
                    ),
                    ButtonSegment(
                      value: _By.name,
                      icon: Icon(Icons.person_search_outlined),
                      label: Text('Name'),
                    ),
                    ButtonSegment(
                      value: _By.id,
                      icon: Icon(Icons.badge_outlined),
                      label: Text('Athlete ID'),
                    ),
                  ],
                  selected: {_by},
                  onSelectionChanged: (s) => setState(() {
                    _by = s.single;
                    _input.clear();
                    _searched = false;
                    _result = null;
                    _matches = const [];
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                Text(switch (_by) {
                  _By.id => 'Enter the ID another athlete shared with you.',
                  _By.browse =>
                    'See adult athletes by sport and programme. '
                        'Under-18s can only be found by their ID.',
                  _By.name =>
                    'Search adult athletes by name. Under-18s '
                        'can only be found by their ID.',
                }, style: textTheme.bodyLarge),
                const SizedBox(height: 16),
                if (_by == _By.browse) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: _sport,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sport',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any sport'),
                      ),
                      for (final sport in sports)
                        DropdownMenuItem(
                          value: sport,
                          child: Text(
                            sport == otherSport ? 'Other sports' : sport,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _sport = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AthleteCategory?>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Programme',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any programme'),
                      ),
                      for (final c in AthleteCategory.values)
                        DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ] else
                  TextField(
                    key: ValueKey(_by),
                    controller: _input,
                    decoration: InputDecoration(
                      labelText: _by == _By.id ? 'Athlete ID' : 'Name',
                      hintText: _by == _By.id ? 'AA-7KQ2MX' : 'e.g. Sam Taylor',
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: _by == _By.id
                        ? TextCapitalization.characters
                        : TextCapitalization.words,
                    autocorrect: false,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: Text(_by == _By.browse ? 'Show athletes' : 'Find'),
                ),
                const SizedBox(height: 24),
                if (_searching)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: textTheme.bodyLarge)
                else if (_by != _By.id && _searched && _matches.isEmpty)
                  Text(
                    'Nobody found. Some athletes choose not to show up in '
                    'search; ask them for their athlete ID instead.',
                    style: textTheme.bodyLarge,
                  )
                else if (_by != _By.id)
                  for (final match in _matches) ...[
                    AthleteIdCard(account: match),
                    const SizedBox(height: 12),
                  ]
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
