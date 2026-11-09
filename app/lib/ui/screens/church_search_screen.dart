import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../common.dart';
import '../theme.dart';
import 'feedback_sheet.dart';

/// Platform entry: find a church by name or city, or reopen one of mine.
class ChurchSearchScreen extends ConsumerStatefulWidget {
  const ChurchSearchScreen({super.key});
  @override
  ConsumerState<ChurchSearchScreen> createState() => _ChurchSearchScreenState();
}

class _ChurchSearchScreenState extends ConsumerState<ChurchSearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(churchSearchProvider(_query));
    final signedIn = ref.watch(userIdProvider) != null;
    final mine = signedIn ? ref.watch(myMembershipsProvider).value ?? const [] : const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: l10n.feedback,
            icon: const Icon(Icons.feedback_outlined),
            onPressed: () => showFeedbackSheet(context),
          ),
          _LanguageButton(),
          if (!signedIn)
            TextButton(
              onPressed: () => context.push('/login'),
              child: Text(l10n.signIn, style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.findYourChurch, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            key: const Key('church-search'),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.findYourChurchHint),
            onChanged: (v) => setState(() => _query = v),
          ),
          if (mine.isNotEmpty) ...[
            SectionHeader(title: l10n.myChurches),
            for (final m in mine)
              ListTile(
                leading: const Icon(Icons.church),
                title: Text(m.churchName ?? ''),
                subtitle: m.isActive ? null : Text(l10n.pending),
                onTap: () => context.go('/c/${m.churchSlug}'),
              ),
            const Divider(),
          ],
          const SizedBox(height: 8),
          AsyncView(
            value: results,
            onRetry: () => ref.invalidate(churchSearchProvider(_query)),
            data: (list) => list.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l10n.noChurchFound)))
                : Column(children: [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hexColor(c.primaryColor ?? '#3B2A7A'),
                              foregroundImage: c.logoUrl == null ? null : NetworkImage(c.logoUrl!),
                              child: Text(c.name.characters.first, style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(c.name),
                            subtitle: Text([?c.city, ?c.country].join(', ')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/c/${c.slug}'),
                          ),
                        ),
                      ),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _LanguageButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(localeProvider).languageCode;
    return TextButton(
      key: const Key('language-toggle'),
      onPressed: () => ref.read(localeProvider.notifier).set(code == 'fr' ? 'en' : 'fr'),
      child: Text(code == 'fr' ? 'EN' : 'FR', style: const TextStyle(color: Colors.white)),
    );
  }
}
