import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// Customer-initiated termination request. We deliberately route this
/// through the ticket system (per PRD §10) rather than the M7
/// voluntary-termination usecase: CS Supervisor still owns approval,
/// and this gives us a single inbox for cancellation triage.
class TerminateRequestPage extends StatefulWidget {
  const TerminateRequestPage({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<TerminateRequestPage> createState() => _TerminateRequestPageState();
}

class _TerminateRequestPageState extends State<TerminateRequestPage> {
  String _reason = 'moving';
  final _notes = TextEditingController();
  bool _busy = false;
  bool _confirmed = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_confirmed) {
      setState(() => _error = 'Please confirm you want to terminate the service.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.dio.post<Map<String, dynamic>>(
        '/portal/termination',
        data: {
          'reason': _reasonLabel(_reason),
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Termination request opened. A CS Supervisor will reach out.')),
      );
      GoRouter.of(context).pop(true);
    } catch (e) {
      // Wave 29 — humanize error.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _reasonLabel(String key) {
    switch (key) {
      case 'moving':
        return 'Moving / address change';
      case 'cost':
        return 'Cost / budget';
      case 'switching':
        return 'Switching to another provider';
      case 'quality':
        return 'Service quality concerns';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Terminate service'),
      body: Column(children: [
        const FadeSlideIn(
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: IonDisplayTitle(
              eyebrow: 'Account',
              title: 'Terminate service',
              subtitle: 'End your ION subscription. We\'ll guide you through.',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          // Hero red warning card — termination is a destructive flow.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFB91C1C), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This will end your ION service. A CS supervisor will call you to confirm before anything happens.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB91C1C),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IonSection(
            title: 'Why are you leaving?',
            child: Column(
              children: [
                for (final r in const [
                  ('moving', 'Moving / address change'),
                  ('cost', 'Cost / budget'),
                  ('switching', 'Switching to another provider'),
                  ('quality', 'Service quality concerns'),
                  ('other', 'Other'),
                ])
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.$2,
                      style: const TextStyle(
                        fontSize: 14,
                        color: IonColors.ink,
                      ),
                    ),
                    value: r.$1,
                    groupValue: _reason,
                    onChanged: (v) => setState(() => _reason = v ?? 'other'),
                    activeColor: IonColors.ion500,
                  ),
              ],
            ),
          ),
          IonSection(
            title: 'Details',
            child: IonField(
              label: 'Anything else (optional)',
              controller: _notes,
              maxLines: 4,
              minLines: 3,
            ),
          ),
          IonSection(
            title: 'Confirm',
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I understand my service will be terminated after CS confirmation.',
                style: TextStyle(fontSize: 13, color: IonColors.ink),
              ),
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              activeColor: const Color(0xFFB91C1C),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: IonErrorBanner(message: _error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: IonSecondaryButton(
              label: _busy ? 'Submitting…' : 'Request termination',
              icon: Icons.power_settings_new_rounded,
              destructive: true,
              onPressed: _busy ? null : _submit,
            ),
          ),
        ],
      )),
      ]),
    );
  }
}
