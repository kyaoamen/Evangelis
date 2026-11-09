import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../data/repository.dart';

/// Keeps downloaded Bible translations on the device so they read offline.
abstract class BibleStore {
  Future<Bible?> load(String translation);
  Future<Bible> download(Repository repo, String translation);
}

String bibleCodeFor(String locale) => locale == 'en' ? 'KJV' : 'LSG1910';

/// Files under the app documents directory (iOS / Android).
class FileBibleStore implements BibleStore {
  final _cache = <String, Bible>{};

  Future<File> _file(String t) async =>
      File('${(await getApplicationDocumentsDirectory()).path}/bible_$t.json');

  @override
  Future<Bible?> load(String translation) async {
    if (_cache[translation] case final b?) return b;
    final f = await _file(translation);
    if (!await f.exists()) return null;
    final bible = await compute(_parse, await f.readAsString());
    return _cache[translation] = bible;
  }

  @override
  Future<Bible> download(Repository repo, String translation) async {
    final json = await repo.downloadBibleJson(translation);
    final bible = await compute(_parse, json); // validate before saving
    final f = await _file(translation);
    final tmp = File('${f.path}.part');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
    return _cache[translation] = bible;
  }
}

/// In memory only (web preview and tests).
class MemoryBibleStore implements BibleStore {
  final _cache = <String, Bible>{};

  @override
  Future<Bible?> load(String translation) async => _cache[translation];

  @override
  Future<Bible> download(Repository repo, String translation) async =>
      _cache[translation] = _parse(await repo.downloadBibleJson(translation));
}

Bible _parse(String json) => Bible.fromJson(jsonDecode(json) as Map<String, dynamic>);
