import 'models.dart';

/// Everything the app needs from the backend. Implemented by
/// [SupabaseRepository] (production) and [DemoRepository] (demo + tests).
abstract class Repository {
  // Auth
  String? get currentUserId;
  Stream<String?> authChanges();
  Future<void> sendOtp(String email);
  Future<void> verifyOtp(String email, String code);
  Future<void> signOut();

  // Churches & membership
  Future<List<ChurchSummary>> searchChurches(String query);
  Future<Church?> churchBySlug(String slug);
  Future<Membership?> myMembership(String churchId);
  Future<List<Membership>> myMemberships();
  Future<Membership> joinChurch(String churchId, {String? inviteCode});
  Future<void> leaveChurch(String churchId);

  // Content
  Future<List<EventCategory>> categories(String churchId);
  Future<List<ChurchEvent>> upcomingEvents(String churchId);
  Future<ChurchEvent?> event(String eventId);
  Future<EventSeats?> seats(String eventId);
  Future<List<Announcement>> announcements(String churchId);
  Future<Verse?> verseOfDay(String churchId, String locale);

  // Registrations
  Future<Registration?> myRegistration(String eventId);
  Future<List<Registration>> myRegistrations(String churchId);
  Future<Registration> register(String eventId, int seats);
  Future<void> cancelRegistration(String registrationId);

  // Profile & privacy
  Future<Profile?> myProfile();
  Future<void> updateProfile({String? firstName, String? lastName, String? phone, String? locale});
  Future<Map<String, dynamic>> exportMyData();
  Future<void> deleteMyData();

  // Pilot feedback
  Future<void> sendFeedback({String? churchId, required String kind, required String message, String? screen, String? platform});

  // Bible: raw JSON for a translation (downloaded once, then stored on device)
  Future<String> downloadBibleJson(String translation);
}
