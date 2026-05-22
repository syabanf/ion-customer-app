import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// Customer-initiated relocation request. Server records it as
/// `pending_survey`; NOC + Sales approve via the staff Approvals
/// queue (sales_app /approvals).
class RelocationRequestPage extends StatefulWidget {
  const RelocationRequestPage({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<RelocationRequestPage> createState() => _RelocationRequestPageState();
}

class _RelocationRequestPageState extends State<RelocationRequestPage> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'New address is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.dio.post<Map<String, dynamic>>(
        '/portal/relocation',
        data: {
          'to_address': _address.text.trim(),
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Relocation request submitted. We\'ll survey the new address.')),
      );
      GoRouter.of(context).pop(true);
    } catch (e) {
      // Wave 29 — humanize error.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Move address'),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'Services',
              title: 'Move address',
              subtitle: 'Tell us your new place; we\'ll relocate your line.',
            ),
          ),
          const SizedBox(height: 12),
          IonSection(
            title: 'New address',
            child: IonField(
              label: 'Where are you moving to?',
              hint: 'Full street + city',
              controller: _address,
              maxLines: 3,
              minLines: 2,
              leading: Icons.place_outlined,
            ),
          ),
          IonSection(
            title: 'Notes',
            child: IonField(
              label: 'Anything the survey team should know?',
              hint: 'Optional',
              controller: _notes,
              maxLines: 3,
              minLines: 2,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: IonErrorBanner(message: _error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: IonPrimaryButton(
              label: _busy ? 'Submitting…' : 'Request relocation',
              icon: Icons.location_on_outlined,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'We\'ll run a coverage check at the new address before scheduling the install.',
              style: TextStyle(
                fontSize: 12,
                color: IonColors.inkMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
