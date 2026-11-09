import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../services/bible_store.dart';

/// Overridden in main() / tests.
final repositoryProvider = Provider<Repository>((ref) => throw UnimplementedError());
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final bibleStoreProvider = Provider<BibleStore>((ref) => throw UnimplementedError());

// ---------------------------------------------------------------- auth
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final repo = ref.watch(repositoryProvider);
  yield repo.currentUserId;
  yield* repo.authChanges();
});

/// Current user id, synchronously (null while signed out).
final userIdProvider = Provider<String?>((ref) =>
    ref.watch(authUserIdProvider).value ?? ref.watch(repositoryProvider).currentUserId);

// ---------------------------------------------------------------- locale
class LocaleController extends Notifier<Locale> {
  static const key = 'locale';

  @override
  Locale build() {
    final saved = ref.watch(prefsProvider).getString(key);
    if (saved != null) return Locale(saved);
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return Locale(device == 'en' ? 'en' : 'fr');
  }

  void set(String code) {
    ref.read(prefsProvider).setString(key, code);
    state = Locale(code);
    if (ref.read(userIdProvider) != null) {
      unawaited(ref.read(repositoryProvider).updateProfile(locale: code).catchError((_) {}));
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

// ---------------------------------------------------------------- active church
/// Slug of the church the user last opened; persisted across launches.
class ActiveChurchController extends Notifier<String?> {
  static const key = 'active_church_slug';

  @override
  String? build() => ref.watch(prefsProvider).getString(key);

  void set(String? slug) {
    final prefs = ref.read(prefsProvider);
    slug == null ? prefs.remove(key) : prefs.setString(key, slug);
    state = slug;
  }
}

final activeChurchSlugProvider = NotifierProvider<ActiveChurchController, String?>(ActiveChurchController.new);

// ---------------------------------------------------------------- data
final churchSearchProvider = FutureProvider.autoDispose.family<List<ChurchSummary>, String>(
  (ref, query) => ref.watch(repositoryProvider).searchChurches(query),
);

final churchProvider = FutureProvider.family<Church?, String>(
  (ref, slug) => ref.watch(repositoryProvider).churchBySlug(slug),
);

final membershipProvider = FutureProvider.family<Membership?, String>((ref, churchId) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).myMembership(churchId);
});

final myMembershipsProvider = FutureProvider<List<Membership>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).myMemberships();
});

final categoriesProvider = FutureProvider.family<List<EventCategory>, String>(
  (ref, churchId) => ref.watch(repositoryProvider).categories(churchId),
);

/// Content visibility depends on membership, so refetch when it changes.
final eventsProvider = FutureProvider.family<List<ChurchEvent>, String>((ref, churchId) async {
  await ref.watch(membershipProvider(churchId).future);
  return ref.watch(repositoryProvider).upcomingEvents(churchId);
});

final eventProvider = FutureProvider.autoDispose.family<ChurchEvent?, String>((ref, eventId) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).event(eventId);
});

final seatsProvider = FutureProvider.autoDispose.family<EventSeats?, String>(
  (ref, eventId) => ref.watch(repositoryProvider).seats(eventId),
);

final myRegistrationProvider = FutureProvider.autoDispose.family<Registration?, String>((ref, eventId) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).myRegistration(eventId);
});

final myRegistrationsProvider = FutureProvider.autoDispose.family<List<Registration>, String>((ref, churchId) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).myRegistrations(churchId);
});

final announcementsProvider = FutureProvider.family<List<Announcement>, String>((ref, churchId) async {
  await ref.watch(membershipProvider(churchId).future);
  return ref.watch(repositoryProvider).announcements(churchId);
});

final verseProvider = FutureProvider.family<Verse?, String>((ref, churchId) {
  final locale = ref.watch(localeProvider).languageCode;
  return ref.watch(repositoryProvider).verseOfDay(churchId, locale);
});

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repositoryProvider).myProfile();
});

/// Refresh everything that depends on a church's membership.
void invalidateChurch(WidgetRef ref, String churchId) {
  ref.invalidate(membershipProvider(churchId));
  ref.invalidate(myMembershipsProvider);
  ref.invalidate(eventsProvider(churchId));
  ref.invalidate(announcementsProvider(churchId));
}
