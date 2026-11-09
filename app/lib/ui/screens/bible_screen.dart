import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../services/bible_store.dart';
import '../../state/providers.dart';
import '../common.dart';

/// The Bible translation for the current language, read from the device.
final offlineBibleProvider = FutureProvider<Bible?>((ref) {
  final code = bibleCodeFor(ref.watch(localeProvider).languageCode);
  return ref.watch(bibleStoreProvider).load(code);
});

/// Offline Bible reader. The translation is downloaded once, then read from
/// the device with no connection needed.
class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});
  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  bool _downloading = false;
  BibleBook? _book;
  int _chapter = 1;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final code = bibleCodeFor(ref.read(localeProvider).languageCode);
      await ref.read(bibleStoreProvider).download(ref.read(repositoryProvider), code);
      ref.invalidate(offlineBibleProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bible = ref.watch(offlineBibleProvider);
    ref.listen(localeProvider, (_, _) => setState(() => _book = null));
    return AsyncView(
      value: bible,
      data: (b) {
        if (b == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.download_for_offline_outlined, size: 56),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('bible-download'),
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(_downloading ? l10n.bibleDownloading : l10n.bibleDownload),
                ),
              ]),
            ),
          );
        }
        final book = _book;
        if (book == null) {
          return ListView(children: [
            ListTile(
              leading: const Icon(Icons.offline_pin, color: Colors.green),
              title: Text(b.name),
              subtitle: Text(l10n.bibleOffline),
            ),
            const Divider(height: 1),
            for (final bk in b.books)
              ListTile(
                title: Text(bk.name),
                trailing: Text('${bk.chapters.length}'),
                onTap: () => setState(() {
                  _book = bk;
                  _chapter = 1;
                }),
              ),
          ]);
        }
        final verses = book.chapters[_chapter - 1];
        return Column(children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _book = null)),
              Expanded(
                child: Text('${book.name} · ${l10n.chapter(_chapter)}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _chapter > 1 ? () => setState(() => _chapter--) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _chapter < book.chapters.length ? () => setState(() => _chapter++) : null,
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: verses.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '${i + 1}  ',
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextSpan(text: verses[i], style: const TextStyle(fontSize: 17, height: 1.5)),
                ])),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
