import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../common.dart';

/// Join a church: explicit GDPR consent (art. 9) + optional invite code.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _code = TextEditingController();
  bool _consent = false;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final church = ref.watch(churchProvider(widget.slug)).value;
    if (church == null) return const SizedBox.shrink();
    if (ref.watch(userIdProvider) == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.church_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(church.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.joinSignInHint, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/login?next=/c/${widget.slug}/join'),
              child: Text(l10n.signIn),
            ),
          ]),
        ),
      );
    }
    final inviteOnly = church.joinMode == 'invite';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.joinChurch, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(church.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: inviteOnly ? l10n.inviteCodeRequired : l10n.inviteCode),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          key: const Key('consent'),
          value: _consent,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() => _consent = v ?? false),
          title: Text(l10n.joinConsent(church.name)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('join-submit'),
          onPressed: !_consent || _busy || (inviteOnly && _code.text.trim().isEmpty)
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final m = await ref
                        .read(repositoryProvider)
                        .joinChurch(church.id, inviteCode: _code.text.trim().isEmpty ? null : _code.text.trim());
                    invalidateChurch(ref, church.id);
                    if (!context.mounted) return;
                    if (m.status == MembershipStatus.pending) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.joinPending)));
                    }
                    context.go('/c/${widget.slug}');
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(l10n.joinChurch),
        ),
      ],
    );
  }
}
