import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

class NewTicketPage extends StatefulWidget {
  const NewTicketPage({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  String _category = 'no_internet';
  String _priority = 'medium';
  final _summary = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _summary.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_summary.text.trim().isEmpty) {
      setState(() => _error = 'Summary is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.dio.post<Map<String, dynamic>>(
        '/portal/tickets',
        data: {
          'category': _category,
          'priority': _priority,
          'summary': _summary.text.trim(),
          'description': _description.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket submitted')),
      );
      GoRouter.of(context).pop(true);
    } catch (e) {
      // Wave 29 — humanize any thrown error (DioException, ApiException,
      // TimeoutException) into a single customer-friendly message via
      // IonError.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'New ticket'),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'Support',
              title: 'New ticket',
              subtitle: 'Report an issue and our team will jump in.',
            ),
          ),
          const SizedBox(height: 12),
          IonSection(
            title: 'What\'s happening?',
            child: Column(
              children: [
                IonSelect<String>(
                  label: 'Category',
                  value: _category,
                  items: const [
                    IonSelectItem('no_internet', 'No internet'),
                    IonSelectItem('slow_speed', 'Slow speed'),
                    IonSelectItem('frequent_drops', 'Frequent drops'),
                    IonSelectItem('equipment_damage', 'Equipment damage'),
                    IonSelectItem('billing_dispute', 'Billing dispute'),
                    IonSelectItem('other', 'Other'),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 12),
                IonSelect<String>(
                  label: 'Priority',
                  value: _priority,
                  items: const [
                    IonSelectItem('high', 'High'),
                    IonSelectItem('medium', 'Medium'),
                    IonSelectItem('low', 'Low'),
                  ],
                  onChanged: (v) => setState(() => _priority = v),
                ),
              ],
            ),
          ),
          IonSection(
            title: 'Details',
            child: Column(
              children: [
                IonField(
                  label: 'Summary',
                  hint: 'One-line description',
                  controller: _summary,
                ),
                const SizedBox(height: 12),
                IonField(
                  label: 'Description (optional)',
                  hint: 'When did it start? Anything you tried?',
                  controller: _description,
                  maxLines: 5,
                  minLines: 4,
                ),
              ],
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
              label: _busy ? 'Submitting…' : 'Submit ticket',
              icon: Icons.send_rounded,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
