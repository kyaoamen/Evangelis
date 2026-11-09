import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../common.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final church = ref.watch(churchProvider(widget.slug)).value;
    if (church == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cats = ref.watch(categoriesProvider(church.id)).value ?? const [];
    final events = ref.watch(eventsProvider(church.id));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchEvents, isDense: true),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(l10n.allCategories),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
            ),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(c.name.tr(context, church.defaultLocale)),
                  selected: _category == c.id,
                  onSelected: (_) => setState(() => _category = c.id),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: AsyncView(
          value: events,
          onRetry: () => ref.invalidate(eventsProvider(church.id)),
          data: (list) {
            final shown = list.where((e) {
              if (_category != null && e.categoryId != _category) return false;
              if (_query.isEmpty) return true;
              final hay = '${e.title.tr(context, church.defaultLocale)} ${e.location ?? ''}'.toLowerCase();
              return hay.contains(_query);
            }).toList();
            if (shown.isEmpty) return Center(child: Text(l10n.noEvents));
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(eventsProvider(church.id)),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => EventTile(
                  event: shown[i],
                  fallbackLocale: church.defaultLocale,
                  onTap: () => context.go('/c/${widget.slug}/events/${shown[i].id}'),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
