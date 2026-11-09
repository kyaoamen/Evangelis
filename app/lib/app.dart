import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n/gen/app_localizations.dart';
import 'state/providers.dart';
import 'ui/screens/announcements_screen.dart';
import 'ui/screens/bible_screen.dart';
import 'ui/screens/church_search_screen.dart';
import 'ui/screens/church_shell.dart';
import 'ui/screens/event_detail_screen.dart';
import 'ui/screens/events_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/join_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/theme.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Routes. A church's space lives under `/c/<slug>`, so an invite link or QR code
/// (`https://<domain>/c/<slug>`) opens that church directly.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) {
          final slug = ref.read(activeChurchSlugProvider);
          return slug == null ? '/churches' : '/c/$slug';
        },
      ),
      GoRoute(path: '/churches', builder: (_, _) => const ChurchSearchScreen()),
      GoRoute(path: '/login', builder: (_, s) => LoginScreen(next: s.uri.queryParameters['next'])),
      ShellRoute(
        builder: (_, s, child) => ChurchShell(
          key: ValueKey(s.pathParameters['slug']),
          slug: s.pathParameters['slug']!,
          location: s.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/c/:slug',
            builder: (_, s) => HomeScreen(slug: s.pathParameters['slug']!),
            routes: [
              GoRoute(path: 'join', builder: (_, s) => JoinScreen(slug: s.pathParameters['slug']!)),
              GoRoute(path: 'events', builder: (_, s) => EventsScreen(slug: s.pathParameters['slug']!)),
              GoRoute(path: 'bible', builder: (_, _) => const BibleScreen()),
              GoRoute(path: 'news', builder: (_, s) => AnnouncementsScreen(slug: s.pathParameters['slug']!)),
              GoRoute(path: 'profile', builder: (_, s) => ProfileScreen(slug: s.pathParameters['slug']!)),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/c/:slug/events/:eventId',
        builder: (_, s) => ChurchThemed(
          slug: s.pathParameters['slug']!,
          child: EventDetailScreen(slug: s.pathParameters['slug']!, eventId: s.pathParameters['eventId']!),
        ),
      ),
    ],
  );
});

/// Applies a church's theme to a page shown outside the church shell.
class ChurchThemed extends ConsumerWidget {
  const ChurchThemed({super.key, required this.slug, required this.child});
  final String slug;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final church = ref.watch(churchProvider(slug)).value;
    if (church == null) return child;
    return Theme(data: churchTheme(church.branding, Theme.of(context).brightness), child: child);
  }
}

class EvangelisApp extends ConsumerWidget {
  const EvangelisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Evangelis',
        debugShowCheckedModeBanner: false,
        theme: platformTheme(Brightness.light),
        darkTheme: platformTheme(Brightness.dark),
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: ref.watch(routerProvider),
      );
}
