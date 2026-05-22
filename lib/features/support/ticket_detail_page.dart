import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// TicketDetailPage — full ticket view with the agent ↔ customer
/// timeline and an inline reply box. When the ticket is resolved/
/// closed and CSAT hasn't been filed yet, the page shows a stars
/// rating block.
class TicketDetailPage extends StatefulWidget {
  const TicketDetailPage({super.key, required this.api, required this.ticketId});
  final PortalAuthApi api;
  final String ticketId;

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  late Future<_Bundle> _future;
  final _reply = TextEditingController();
  bool _busy = false;
  final List<String> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Bundle> _load() async {
    final detail = await widget.api.dio
        .get<Map<String, dynamic>>('/portal/tickets/${widget.ticketId}');
    final messages = await widget.api.dio.get<Map<String, dynamic>>(
        '/portal/tickets/${widget.ticketId}/messages');
    return _Bundle(
      detail: detail.data ?? const <String, dynamic>{},
      messages: ((messages.data?['items'] as List<dynamic>?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final body = _reply.text.trim();
    if (body.isEmpty && _pendingAttachments.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.api.dio.post(
        '/portal/tickets/${widget.ticketId}/messages',
        data: {
          'body': body,
          if (_pendingAttachments.isNotEmpty) 'attachments': _pendingAttachments,
        },
      );
      _reply.clear();
      _pendingAttachments.clear();
      setState(() => _future = _load());
    } catch (e) {
      // Wave 29 — humanize the error through IonError. Covers DioException,
      // ApiException, TimeoutException, etc. with friendly copy.
      if (!mounted) return;
      IonError.snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachPhoto() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (x == null) return;
      setState(() => _busy = true);
      final bytes = await File(x.path).readAsBytes();
      // Customer-portal token works against /api/uploads/photos since
      // the gateway forwards portal sessions to the field uploads endpoint.
      final r = await widget.api.dio.post<Map<String, dynamic>>(
        '/api/uploads/photos',
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          method: 'POST',
          contentType: 'image/jpeg',
          headers: {'Content-Length': bytes.length.toString()},
        ),
      );
      final url = r.data?['object_url'] as String?;
      if (url != null) {
        setState(() => _pendingAttachments.add(url));
      }
    } catch (e) {
      if (!mounted) return;
      IonError.snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCSAT(int score) async {
    setState(() => _busy = true);
    try {
      await widget.api.dio.post(
        '/portal/tickets/${widget.ticketId}/csat',
        data: {'score': score},
      );
      if (!mounted) return;
      // Wave 25 — confetti + branded snackbar on CSAT submit success.
      IonConfetti.celebrate(context);
      IonSnackbar.show(
        context,
        'Thanks for the feedback!',
        icon: Icons.celebration_outlined,
      );
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      IonError.snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Ticket'),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: IonColors.ion500),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: IonErrorBanner(message: 'Failed: ${snap.error}'),
            );
          }
          final d = snap.data!.detail;
          final msgs = snap.data!.messages;
          final status = d['status'] as String? ?? '';
          final resolved = status == 'resolved' || status == 'closed';
          final csatFiled = d['csat_score'] != null;
          // Wave 22 — dashboard treatment: display title with ticket
          // number eyebrow + summary header + status pill + threaded
          // conversation under a chip divider.
          final ticketNum = (d['ticket_number'] as String?) ?? '';
          final summary = (d['summary'] as String?) ?? '—';
          final cat = (d['category'] as String?) ?? '';
          final pri = (d['priority'] as String?) ?? '';
          IonStatusTone statusTone() {
            if (resolved) return IonStatusTone.success;
            if (status == 'in_progress') return IonStatusTone.info;
            if (status == 'open') return IonStatusTone.warning;
            return IonStatusTone.neutral;
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
            children: [
              FadeSlideIn(
                child: IonDisplayTitle(
                  eyebrow: ticketNum.isEmpty ? 'Ticket' : '#${ticketNum.substring(ticketNum.length > 8 ? ticketNum.length - 8 : 0)}',
                  title: summary,
                  subtitle:
                      '${_humanCat(cat)} · ${pri.toUpperCase()} priority',
                  trailing: IonStatusPill(
                    label: status,
                    tone: statusTone(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SummaryCard(detail: d),
              ),
              const SizedBox(height: 14),
              if (resolved && !csatFiled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CsatCard(onSubmit: _busy ? null : _submitCSAT),
                ),
              if (resolved && csatFiled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Thanks — you rated this ${d['csat_score']}/5.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: IonColors.inkMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Conversation participants — IonAvatarStack shows the
              // distinct authors at a glance before scrolling the thread.
              if (msgs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: Row(
                    children: [
                      IonAvatarStack(
                        avatars: _authorAvatars(msgs),
                        size: 28,
                        overlap: 10,
                        extra: _authorAvatars(msgs).length > 3
                            ? '+${_distinctAuthors(msgs).length - 3}'
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${msgs.length} message${msgs.length == 1 ? '' : 's'} · ${_distinctAuthors(msgs).length} participant${_distinctAuthors(msgs).length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: IonColors.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const IonChipDivider(label: 'Conversation'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: msgs.isEmpty
                    ? const IonEmptyState(
                        icon: Icons.forum_outlined,
                        art: IonArtKind.inbox,
                        title: 'No replies yet',
                        hint: 'An agent will respond soon.',
                      )
                    : Column(children: [
                        for (var i = 0; i < msgs.length; i++) ...[
                          FadeSlideIn(
                            delay: Duration(
                                milliseconds: 30 * i.clamp(0, 12)),
                            child: _MessageBubble(message: msgs[i]),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ]),
              ),
              const SizedBox(height: 14),
              if (!resolved)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: IonField(
                    label: 'Add a reply',
                    hint: 'Type your message…',
                    controller: _reply,
                    maxLines: 4,
                    minLines: 2,
                  ),
                ),
              if (!resolved && _pendingAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _pendingAttachments.length; i++)
                        _AttachmentThumbnail(
                          url: _pendingAttachments[i],
                          onRemove: () =>
                              setState(() => _pendingAttachments.removeAt(i)),
                        ),
                    ],
                  ),
                ),
              ],
              if (!resolved) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: IonSecondaryButton(
                          label: 'Attach photo',
                          icon: Icons.photo_camera_outlined,
                          onPressed: _busy ? null : _attachPhoto,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IonPrimaryButton(
                          label: _busy ? 'Sending…' : 'Send',
                          icon: Icons.send_rounded,
                          loading: _busy,
                          onPressed: _sendReply,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Map the wire-format category enum to a human-readable label.
  String _humanCat(String cat) {
    return switch (cat) {
      'no_internet' => 'No internet',
      'slow_speed' => 'Slow speed',
      'frequent_drops' => 'Frequent drops',
      'equipment_damage' => 'Equipment damage',
      'billing_dispute' => 'Billing dispute',
      _ => cat.replaceAll('_', ' '),
    };
  }

  /// Unique author kinds across the thread — preserves order of first
  /// appearance. Used to populate the conversation IonAvatarStack.
  List<String> _distinctAuthors(List<Map<String, dynamic>> msgs) {
    final seen = <String>{};
    final order = <String>[];
    for (final m in msgs) {
      final kind = (m['author_kind'] as String?) ?? 'user';
      if (seen.add(kind)) order.add(kind);
    }
    return order;
  }

  /// Map distinct author kinds → IonAvatar list (max 3 shown, rest
  /// rolled into the `extra` chip).
  List<IonAvatar> _authorAvatars(List<Map<String, dynamic>> msgs) {
    final kinds = _distinctAuthors(msgs).take(3).toList();
    return [
      for (final k in kinds)
        IonAvatar(
          initials: switch (k) {
            'agent' => 'CS',
            'system' => 'IO',
            'user' => 'YO',
            _ => k.substring(0, 1).toUpperCase(),
          },
          color: switch (k) {
            'agent' => IonColors.indigo500.withValues(alpha: 0.15),
            'system' => IonColors.inkMuted.withValues(alpha: 0.18),
            'user' => IonColors.mint500.withValues(alpha: 0.18),
            _ => IonColors.ion100,
          },
        ),
    ];
  }
}

class _Bundle {
  _Bundle({required this.detail, required this.messages});
  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>> messages;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});
  final Map<String, dynamic> detail;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail['summary'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: IonColors.ink,
                  ),
                ),
              ),
              _statusChip(detail['status'] as String? ?? ''),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail['ticket_number'] as String? ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: IonColors.inkMuted,
            ),
          ),
          if ((detail['description'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              detail['description'] as String,
              style: const TextStyle(
                fontSize: 13,
                color: IonColors.inkSoft,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String s) {
    Color c;
    switch (s) {
      case 'resolved':
      case 'closed':
        c = const Color(0xFF15803D);
        break;
      case 'in_progress':
        c = IonColors.ion600;
        break;
      case 'pending_customer':
        c = const Color(0xFF7E22CE);
        break;
      default:
        c = const Color(0xFFB45309);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: c,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Map<String, dynamic> message;
  @override
  Widget build(BuildContext context) {
    final isAgent = (message['author_kind'] as String?) == 'agent';
    final isSystem = (message['author_kind'] as String?) == 'system';
    final created = DateTime.tryParse(message['created_at'] as String? ?? '');
    return Align(
      alignment: isAgent ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isSystem
              ? const Color(0xFFF3E8FF)
              : (isAgent ? Colors.white : IonColors.ion500),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isAgent ? 4 : 14),
            bottomRight: Radius.circular(isAgent ? 14 : 4),
          ),
          boxShadow: isAgent ? IonForm.cardShadow : null,
        ),
        child: Column(
          crossAxisAlignment:
              isAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if ((message['body'] as String? ?? '').isNotEmpty)
              Text(
                message['body'] as String? ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: isAgent ? IonColors.ink : Colors.white,
                  height: 1.35,
                ),
              ),
            if ((message['attachments'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final url in (message['attachments'] as List).cast<String>())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        url,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 96,
                          height: 96,
                          color: IonColors.separatorLight,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 18, color: IonColors.inkMuted),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (created != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d · h:mm a').format(created.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: isAgent
                      ? IonColors.inkMuted
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CsatCard extends StatelessWidget {
  const _CsatCard({required this.onSubmit});
  final void Function(int)? onSubmit;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How did we do?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: IonColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a star to rate this ticket\'s resolution.',
            style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: onSubmit == null ? null : () => onSubmit!(i),
                  icon: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFBBF24),
                    size: 32,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// _AttachmentThumbnail — preview of a just-uploaded photo in the
/// reply composer. Uses Image.network because the uploads gateway has
/// already persisted the bytes; the URL is signed for the customer's
/// portal token via the same path we'll embed in the outbound message
/// payload. A small X overlay removes the URL from the pending list.
///
/// 64×64 with rounded corners — matches the inline attachment chip
/// row in the message list so the customer sees roughly what their
/// message will look like once sent.
class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            // While the bytes haven't loaded, show the same chip the
            // older UI used. Keeps the layout from shifting.
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 64,
                height: 64,
                color: IonColors.ion50,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: IonColors.ion400,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              width: 64,
              height: 64,
              color: IonColors.ion50,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: IonColors.inkMuted,
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: IonColors.inkSoft,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
