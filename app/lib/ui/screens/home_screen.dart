import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final church = ref.watch(churchProvider(slug)).value;
    if (church == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final events = ref.watch(eventsProvider(church.id));
    final news = ref.watch(announcementsProvider(church.id));
    final verse = ref.watch(verseProvider(church.id));
    final fb = church.defaultLocale;

    return RefreshIndicator(
      onRefresh: () async {
        invalidateChurch(ref, church.id);
        ref.invalidate(verseProvider(church.id));
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Welcome(church: church),
          MembershipBanner(church: church),
          if (verse.value case final v?) _VerseCard(verse: v),
          SectionHeader(title: l10n.upcomingEvents, onSeeAll: () => context.go('/c/$slug/events')),
          AsyncView(
            value: events,
            onRetry: () => ref.invalidate(eventsProvider(church.id)),
            data: (list) => list.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.noEvents))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      for (final e in list.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: EventTile(
                            event: e,
                            fallbackLocale: fb,
                            onTap: () => context.go('/c/$slug/events/${e.id}'),
                          ),
                        ),
                    ]),
                  ),
          ),
          SectionHeader(title: l10n.latestAnnouncements, onSeeAll: () => context.go('/c/$slug/news')),
          AsyncView(
            value: news,
            onRetry: () => ref.invalidate(announcementsProvider(church.id)),
            data: (list) => list.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.noAnnouncements))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final a in list.take(2))
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: AnnouncementCard(item: a, fallback: fb)),
                    ]),
                  ),
          ),
          SectionHeader(title: l10n.aboutChurch),
          ChurchContact(church: church),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.church});
  final Church church;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = church.branding;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, 0.55)!]),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (b.coverUrl != null)
          AspectRatio(aspectRatio: 16 / 9, child: CachedNetworkImage(imageUrl: b.coverUrl!, fit: BoxFit.contain)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            b.welcomeText?.tr(context, church.defaultLocale) ?? church.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// Visitor -> join button; pending -> notice; member -> nothing.
class MembershipBanner extends ConsumerWidget {
  const MembershipBanner({super.key, required this.church});
  final Church church;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final m = ref.watch(membershipProvider(church.id)).value;
    if (m != null && m.isActive) return const SizedBox.shrink();
    final pending = m?.status == MembershipStatus.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(pending ? Icons.hourglass_top : Icons.waving_hand_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(pending ? l10n.joinPending : l10n.visitorBanner)),
            if (!pending)
              FilledButton(
                key: const Key('join-banner'),
                onPressed: () => context.go('/c/${church.slug}/join'),
                child: Text(l10n.joinChurch),
              ),
          ]),
        ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse});
  final Verse verse;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.verseOfDay.toUpperCase(),
                style: t.labelSmall?.copyWith(letterSpacing: 1.2, color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 8),
            Text('« ${verse.text} »', style: t.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text(verse.reference, style: t.labelLarge),
          ]),
        ),
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item, required this.fallback});
  final Announcement item;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatDay(context, item.publishAt), style: t.labelSmall),
          const SizedBox(height: 4),
          Text(item.title.tr(context, fallback), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(item.body.tr(context, fallback), style: t.bodyMedium),
        ]),
      ),
    );
  }
}

/// Contact block; fields the church left empty are hidden.
class ChurchContact extends StatelessWidget {
  const ChurchContact({super.key, required this.church});
  final Church church;

  @override
  Widget build(BuildContext context) {
    final b = church.branding;
    Widget row(IconData icon, String text, Uri uri) => ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(text),
          onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (b.aboutText != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(b.aboutText!.tr(context, church.defaultLocale)),
          ),
        if (b.address?.isNotEmpty ?? false)
          row(Icons.place_outlined, b.address!, Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': b.address!})),
        if (b.phone?.isNotEmpty ?? false) row(Icons.phone_outlined, b.phone!, Uri(scheme: 'tel', path: b.phone!.replaceAll(' ', ''))),
        if (b.email?.isNotEmpty ?? false) row(Icons.mail_outline, b.email!, Uri(scheme: 'mailto', path: b.email!)),
        if (b.website?.isNotEmpty ?? false) row(Icons.language, b.website!, Uri.parse(b.website!)),
        for (final s in b.socials.entries) row(Icons.open_in_new, s.key, Uri.parse(s.value)),
      ]),
    );
  }
}
