import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../common.dart';
import 'feedback_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final church = ref.watch(churchProvider(slug)).value;
    final signedIn = ref.watch(userIdProvider) != null;
    final lang = ref.watch(localeProvider).languageCode;
    final repo = ref.read(repositoryProvider);

    final language = ListTile(
      leading: const Icon(Icons.translate),
      title: Text(l10n.language),
      trailing: SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'fr', label: Text('FR')), ButtonSegment(value: 'en', label: Text('EN'))],
        selected: {lang},
        onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
      ),
    );

    if (!signedIn) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton(onPressed: () => context.go('/login?next=/c/$slug/profile'), child: Text(l10n.signIn)),
        const SizedBox(height: 16),
        language,
      ]);
    }

    final membership = church == null ? null : ref.watch(membershipProvider(church.id)).value;
    return ListView(children: [
      const _ProfileForm(),
      const Divider(),
      language,
      if (membership != null)
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(church!.name),
          subtitle: Text(membership.isActive ? l10n.member : l10n.pending),
        ),
      if (membership?.isActive ?? false) _MyRegistrations(slug: slug, churchId: church!.id),
      ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text(l10n.switchChurch),
        onTap: () => context.go('/churches'),
      ),
      ListTile(
        key: const Key('feedback-tile'),
        leading: const Icon(Icons.feedback_outlined),
        title: Text(l10n.feedback),
        onTap: () => showFeedbackSheet(context, churchId: church?.id),
      ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(l10n.privacy, style: Theme.of(context).textTheme.titleSmall),
      ),
      ListTile(
        leading: const Icon(Icons.download_outlined),
        title: Text(l10n.exportMyData),
        onTap: () async {
          try {
            final data = await repo.exportMyData();
            await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.dataExported)));
            }
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
      ),
      if (membership != null && membership.role != 'owner')
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.leaveChurch),
          onTap: () async {
            if (!await confirmDialog(context, l10n.leaveChurch)) return;
            try {
              await repo.leaveChurch(church!.id);
              invalidateChurch(ref, church.id);
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
        ),
      ListTile(
        leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        title: Text(l10n.deleteMyData, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        onTap: () async {
          if (!await confirmDialog(context, l10n.deleteMyDataConfirm)) return;
          try {
            await repo.deleteMyData();
            if (church != null) invalidateChurch(ref, church.id);
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.power_settings_new),
        title: Text(l10n.signOut),
        onTap: () async {
          await repo.signOut();
          if (church != null) invalidateChurch(ref, church.id);
        },
      ),
      const SizedBox(height: 24),
    ]);
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();
  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  String? _loadedFor;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _fill(Profile p) {
    if (_loadedFor == p.id) return;
    _loadedFor = p.id;
    _first.text = p.firstName ?? '';
    _last.text = p.lastName ?? '';
    _phone.text = p.phone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider).value;
    if (profile == null) return const SizedBox.shrink();
    _fill(profile);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(profile.email ?? '', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _first, decoration: InputDecoration(labelText: l10n.firstName))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _last, decoration: InputDecoration(labelText: l10n.lastName))),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: l10n.phone),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: () async {
              try {
                await ref.read(repositoryProvider).updateProfile(
                      firstName: _first.text.trim(),
                      lastName: _last.text.trim(),
                      phone: _phone.text.trim(),
                    );
                ref.invalidate(profileProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saved)));
                }
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            child: Text(l10n.save),
          ),
        ),
      ]),
    );
  }
}

class _MyRegistrations extends ConsumerWidget {
  const _MyRegistrations({required this.slug, required this.churchId});
  final String slug, churchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regs = ref.watch(myRegistrationsProvider(churchId)).value ?? const [];
    if (regs.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      leading: const Icon(Icons.confirmation_number_outlined),
      title: Text(context.l10n.myRegistrations),
      children: [
        for (final r in regs)
          ListTile(
            title: Text(r.event?.title.tr(context) ?? ''),
            subtitle: Text(r.event == null ? '' : formatDateTime(context, r.event!.startsAt)),
            trailing: Icon(r.status == RegistrationStatus.confirmed ? Icons.check_circle : Icons.hourglass_top),
            onTap: () => context.go('/c/$slug/events/${r.eventId}'),
          ),
      ],
    );
  }
}
