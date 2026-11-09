import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/providers.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get lang => Localizations.localeOf(this).languageCode;
}

extension I18nX on I18nText {
  String tr(BuildContext context, [String fallback = 'fr']) => of(context.lang, fallback: fallback);
}

String formatDateTime(BuildContext context, DateTime d) =>
    DateFormat.yMMMMEEEEd(context.lang).add_Hm().format(d);
String formatDay(BuildContext context, DateTime d) => DateFormat.MMMd(context.lang).format(d);

/// Loading / error / data for an AsyncValue, with a retry button.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (e, _) => ErrorBox(error: e, onRetry: onRetry),
      );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error is AppError ? error.toString() : context.l10n.errorGeneric, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ]),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 8, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: Text(context.l10n.seeAll)),
        ]),
      );
}

/// Poster image that is never cropped (fits inside its box).
class Poster extends StatelessWidget {
  const Poster({super.key, required this.url, this.height = 180});
  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(Icons.event, size: 48, color: scheme.onPrimaryContainer),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Container(
      height: height,
      color: scheme.surfaceContainerHighest,
      child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.contain, errorWidget: (_, _, _) => placeholder),
    );
  }
}

/// Small "date" badge used on event cards.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text('${date.day}', style: TextStyle(color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(DateFormat.MMM(context.lang).format(date).toUpperCase(),
            style: TextStyle(color: scheme.onPrimary, fontSize: 11)),
      ]),
    );
  }
}

class EventTile extends ConsumerWidget {
  const EventTile({super.key, required this.event, required this.onTap, this.fallbackLocale = 'fr'});
  final ChurchEvent event;
  final VoidCallback onTap;
  final String fallbackLocale;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              DateBadge(date: event.startsAt),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(event.title.tr(context, fallbackLocale),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    [DateFormat.Hm(context.lang).format(event.startsAt), ?event.location].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.membersOnly)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const Icon(Icons.lock_outline, size: 14),
                        const SizedBox(width: 4),
                        Text(context.l10n.membersOnly, style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}

Future<bool> confirmDialog(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.confirm)),
        ],
      ),
    ) ??
    false;

void showError(BuildContext context, Object e) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is AppError ? e.message : context.l10n.errorGeneric)),
    );

/// Current church's default locale, used as the content fallback.
String churchFallback(WidgetRef ref, String slug) =>
    ref.watch(churchProvider(slug)).value?.defaultLocale ?? 'fr';
