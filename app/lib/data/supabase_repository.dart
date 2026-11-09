import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';

const appVersion = '0.1.0-pilot';

class SupabaseRepository implements Repository {
  SupabaseRepository(this._db);
  final SupabaseClient _db;

  static const _eventCols =
      'id, church_id, category_id, title, description, poster_url, starts_at, ends_at, location, '
      'capacity, max_seats_per_registration, registration_open, visibility';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw AppError(e.message);
    } on AuthException catch (e) {
      throw AppError(e.message);
    }
  }

  // ---------------------------------------------------------------- auth
  @override
  String? get currentUserId => _db.auth.currentUser?.id;

  @override
  Stream<String?> authChanges() => _db.auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  Future<void> sendOtp(String email) =>
      _guard(() => _db.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true));

  @override
  Future<void> verifyOtp(String email, String code) =>
      _guard(() => _db.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email));

  @override
  Future<void> signOut() => _db.auth.signOut();

  // ---------------------------------------------------------------- churches
  @override
  Future<List<ChurchSummary>> searchChurches(String query) => _guard(() async {
        final rows = await _db.rpc('search_churches', params: {'p_query': query, 'p_limit': 30}) as List;
        return rows.map((r) => ChurchSummary.fromJson(Map<String, dynamic>.from(r))).toList();
      });

  @override
  Future<Church?> churchBySlug(String slug) => _guard(() async {
        final row = await _db
            .from('churches')
            .select('id, slug, name, city, country, default_locale, join_mode, church_branding(*)')
            .eq('slug', slug)
            .maybeSingle();
        return row == null ? null : Church.fromJson(row);
      });

  @override
  Future<Membership?> myMembership(String churchId) => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return null;
        final row = await _db
            .from('memberships')
            .select('id, church_id, role, status')
            .eq('church_id', churchId)
            .eq('user_id', uid)
            .maybeSingle();
        return row == null ? null : Membership.fromJson(row);
      });

  @override
  Future<List<Membership>> myMemberships() => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return [];
        final rows = await _db
            .from('memberships')
            .select('id, church_id, role, status, churches(name, slug)')
            .eq('user_id', uid)
            .inFilter('status', ['active', 'pending']);
        return rows.map(Membership.fromJson).toList();
      });

  @override
  Future<Membership> joinChurch(String churchId, {String? inviteCode}) => _guard(() async {
        final row = await _db.rpc('join_church', params: {
          'p_church': churchId,
          'p_consent': true,
          'p_invite_code': inviteCode,
        });
        return Membership.fromJson(Map<String, dynamic>.from(row));
      });

  @override
  Future<void> leaveChurch(String churchId) =>
      _guard(() => _db.rpc('leave_church', params: {'p_church': churchId}));

  // ---------------------------------------------------------------- content
  @override
  Future<List<EventCategory>> categories(String churchId) => _guard(() async {
        final rows = await _db.from('event_categories').select('id, name').eq('church_id', churchId).order('sort');
        return rows.map(EventCategory.fromJson).toList();
      });

  @override
  Future<List<ChurchEvent>> upcomingEvents(String churchId) => _guard(() async {
        final rows = await _db
            .from('events')
            .select(_eventCols)
            .eq('church_id', churchId)
            .not('published_at', 'is', null)
            .gte('starts_at', DateTime.now().toUtc().subtract(const Duration(hours: 6)).toIso8601String())
            .order('starts_at');
        return rows.map(ChurchEvent.fromJson).toList();
      });

  @override
  Future<ChurchEvent?> event(String eventId) => _guard(() async {
        final row = await _db.from('events').select(_eventCols).eq('id', eventId).maybeSingle();
        return row == null ? null : ChurchEvent.fromJson(row);
      });

  @override
  Future<EventSeats?> seats(String eventId) => _guard(() async {
        final rows = await _db.rpc('event_seats', params: {'p_event': eventId}) as List;
        return rows.isEmpty ? null : EventSeats.fromJson(Map<String, dynamic>.from(rows.first));
      });

  @override
  Future<List<Announcement>> announcements(String churchId) => _guard(() async {
        final rows = await _db
            .from('announcements')
            .select('id, title, body, image_url, audience, publish_at')
            .eq('church_id', churchId)
            .lte('publish_at', DateTime.now().toUtc().toIso8601String())
            .order('publish_at', ascending: false)
            .limit(50);
        return rows.map(Announcement.fromJson).toList();
      });

  @override
  Future<Verse?> verseOfDay(String churchId, String locale) => _guard(() async {
        final rows = await _db.rpc('verse_of_day', params: {
          'p_church': churchId,
          'p_translation': locale == 'en' ? 'KJV' : 'LSG1910',
        }) as List;
        if (rows.isEmpty) return null;
        return Verse(reference: rows.first['reference'], text: rows.first['text']);
      });

  // ---------------------------------------------------------------- registrations
  @override
  Future<Registration?> myRegistration(String eventId) => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return null;
        final row = await _db
            .from('event_registrations')
            .select('id, event_id, status, seats, qr_token')
            .eq('event_id', eventId)
            .eq('user_id', uid)
            .neq('status', 'cancelled')
            .maybeSingle();
        return row == null ? null : Registration.fromJson(row);
      });

  @override
  Future<List<Registration>> myRegistrations(String churchId) => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return [];
        final rows = await _db
            .from('event_registrations')
            .select('id, event_id, status, seats, qr_token, events($_eventCols)')
            .eq('church_id', churchId)
            .eq('user_id', uid)
            .neq('status', 'cancelled')
            .order('created_at', ascending: false);
        return rows.map(Registration.fromJson).toList();
      });

  @override
  Future<Registration> register(String eventId, int seats) => _guard(() async {
        final row = await _db.rpc('register_for_event', params: {'p_event': eventId, 'p_seats': seats});
        return Registration.fromJson(Map<String, dynamic>.from(row));
      });

  @override
  Future<void> cancelRegistration(String registrationId) =>
      _guard(() => _db.rpc('cancel_registration', params: {'p_registration': registrationId}));

  // ---------------------------------------------------------------- profile
  @override
  Future<Profile?> myProfile() => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return null;
        final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
        return row == null ? null : Profile.fromJson(row);
      });

  @override
  Future<void> updateProfile({String? firstName, String? lastName, String? phone, String? locale}) =>
      _guard(() async {
        await _db.from('profiles').update({
          'first_name': ?firstName,
          'last_name': ?lastName,
          'phone': ?phone,
          'locale': ?locale,
        }).eq('id', currentUserId!);
      });

  @override
  Future<Map<String, dynamic>> exportMyData() =>
      _guard(() async => Map<String, dynamic>.from(await _db.rpc('export_my_data')));

  @override
  Future<void> deleteMyData() => _guard(() => _db.rpc('delete_my_data'));

  // ---------------------------------------------------------------- feedback
  @override
  Future<void> sendFeedback({String? churchId, required String kind, required String message, String? screen, String? platform}) =>
      _guard(() async {
        await _db.from('feedback').insert({
          'church_id': churchId,
          'user_id': currentUserId,
          'kind': kind,
          'message': message.trim(),
          'screen': screen,
          'platform': platform,
          'app_version': appVersion,
        });
      });

  // ---------------------------------------------------------------- bible
  @override
  Future<String> downloadBibleJson(String translation) => _guard(() async {
        final bytes = await _db.storage.from('bible').download('$translation.json');
        return utf8.decode(bytes);
      });
}
