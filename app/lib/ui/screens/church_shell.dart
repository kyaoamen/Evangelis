import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../common.dart';
import '../theme.dart';
import 'feedback_sheet.dart';

/// A church's space: its own theme, header and bottom navigation.
class ChurchShell extends ConsumerStatefulWidget {
  const ChurchShell({super.key, required this.slug, required this.location, required this.child});
  final String slug, location;
  final Widget child;

  static const tabs = ['', 'events', 'bible', 'news', 'profile'];

  int get index {
    final rest = location.split('/').skip(3).firstOrNull ?? '';
    final i = tabs.indexOf(rest);
    return i < 0 ? 0 : i;
  }

  @override
  ConsumerState<ChurchShell> createState() => _ChurchShellState();
}

class _ChurchShellState extends ConsumerState<ChurchShell> {
  @override
  void initState() {
    super.initState();
    // Remember this church for the next launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(activeChurchSlugProvider.notifier).set(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final church = ref.watch(churchProvider(widget.slug));
    return church.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorBox(error: e, onRetry: () => ref.invalidate(churchProvider(widget.slug)))),
      data: (c) {
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.noChurchFound),
                TextButton(
                  onPressed: () {
                    ref.read(activeChurchSlugProvider.notifier).set(null);
                    context.go('/churches');
                  },
                  child: Text(l10n.findYourChurch),
                ),
              ]),
            ),
          );
        }
        return Theme(
          data: churchTheme(c.branding, Theme.of(context).brightness),
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                titleSpacing: 12,
                title: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundImage: c.branding.logoUrl == null ? null : NetworkImage(c.branding.logoUrl!),
                    child: Text(c.name.characters.first, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (c.branding.tagline != null)
                        Text(c.branding.tagline!.tr(context, c.defaultLocale),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ]),
                actions: [
                  IconButton(
                    key: const Key('feedback-button'),
                    tooltip: l10n.feedback,
                    icon: const Icon(Icons.feedback_outlined),
                    onPressed: () => showFeedbackSheet(context, churchId: c.id),
                  ),
                  IconButton(
                    tooltip: l10n.switchChurch,
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => context.go('/churches'),
                  ),
                ],
              ),
              body: widget.child,
              bottomNavigationBar: NavigationBar(
                selectedIndex: widget.index,
                onDestinationSelected: (i) =>
                    context.go(ChurchShell.tabs[i].isEmpty ? '/c/${widget.slug}' : '/c/${widget.slug}/${ChurchShell.tabs[i]}'),
                destinations: [
                  NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.navHome),
                  NavigationDestination(icon: const Icon(Icons.event_outlined), selectedIcon: const Icon(Icons.event), label: l10n.navEvents),
                  NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: l10n.navBible),
                  NavigationDestination(icon: const Icon(Icons.campaign_outlined), selectedIcon: const Icon(Icons.campaign), label: l10n.navNews),
                  NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.navProfile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
