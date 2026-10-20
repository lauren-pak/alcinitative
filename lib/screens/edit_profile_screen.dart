import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/services.dart';
import 'sign_up/profile_step.dart';

/// Correct name, sport, level, programme and topics (PDPA correction).
/// Pops with the updated [Account] when saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.account});

  final Account account;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _draft = widget.account.profile.copy();
  final _nameForm = GlobalKey<FormState>();
  bool _saving = false;

  Future<void> _save() async {
    if (!_nameForm.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = Account(
      uid: widget.account.uid,
      athleteId: widget.account.athleteId,
      profile: _draft,
      joinedAt: widget.account.joinedAt,
    );
    try {
      await Services.profiles.update(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save. Check your connection and try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit my details')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AbsorbPointer(
            absorbing: _saving,
            child: ProfileStep(
              data: _draft,
              submitLabel: 'Save changes',
              onContinue: _save,
              header: Form(
                key: _nameForm,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextFormField(
                    initialValue: _draft.name,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) => _draft.name = v.trim(),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your name'
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
