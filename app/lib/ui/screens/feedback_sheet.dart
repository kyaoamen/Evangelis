import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../common.dart';

String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

/// Bottom sheet where pilot users report a problem or suggest an idea.
Future<void> showFeedbackSheet(BuildContext context, {String? churchId}) {
  final screen = GoRouterState.of(context).uri.path;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _FeedbackForm(churchId: churchId, screen: screen),
    ),
  );
}

class _FeedbackForm extends ConsumerStatefulWidget {
  const _FeedbackForm({this.churchId, required this.screen});
  final String? churchId;
  final String screen;
  @override
  ConsumerState<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends ConsumerState<_FeedbackForm> {
  final _text = TextEditingController();
  String _kind = 'idea';
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final signedIn = ref.watch(userIdProvider) != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.feedbackTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (!signedIn) ...[
            Text(l10n.feedbackSignIn),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/login?next=${Uri.encodeComponent(widget.screen)}');
              },
              child: Text(l10n.signIn),
            ),
          ] else ...[
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'bug', icon: const Icon(Icons.bug_report_outlined), label: Text(l10n.feedbackBug)),
                ButtonSegment(value: 'idea', icon: const Icon(Icons.lightbulb_outline), label: Text(l10n.feedbackIdea)),
                ButtonSegment(value: 'other', label: Text(l10n.feedbackOther)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('feedback-text'),
              controller: _text,
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              decoration: InputDecoration(hintText: l10n.feedbackHint),
              onChanged: (_) => setState(() {}),
            ),
            FilledButton.icon(
              key: const Key('feedback-send'),
              icon: const Icon(Icons.send),
              onPressed: _busy || _text.text.trim().length < 3
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await ref.read(repositoryProvider).sendFeedback(
                              churchId: widget.churchId,
                              kind: _kind,
                              message: _text.text,
                              screen: widget.screen,
                              platform: _platform,
                            );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.feedbackThanks)));
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              label: Text(l10n.feedbackSend),
            ),
          ],
        ]),
      ),
    );
  }
}
