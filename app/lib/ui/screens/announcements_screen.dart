import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../common.dart';
import 'home_screen.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final church = ref.watch(churchProvider(slug)).value;
    if (church == null) return const SizedBox.shrink();
    final news = ref.watch(announcementsProvider(church.id));
    return AsyncView(
      value: news,
      onRetry: () => ref.invalidate(announcementsProvider(church.id)),
      data: (list) => list.isEmpty
          ? Center(child: Text(context.l10n.noAnnouncements))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(announcementsProvider(church.id)),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => AnnouncementCard(item: list[i], fallback: church.defaultLocale),
              ),
            ),
    );
  }
}
