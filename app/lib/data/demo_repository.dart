import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';
import 'repository.dart';

/// In-memory backend for demos (`--dart-define=DEMO=true`) and widget tests.
/// Sign-in accepts any email with the code 123456.
class DemoRepository implements Repository {
  DemoRepository({DateTime? now, this.bibleLoader}) : _now = now ?? DateTime.now() {
    _seed();
  }

  final DateTime _now;
  final Future<String> Function(String translation)? bibleLoader;
  final _auth = StreamController<String?>.broadcast();
  String? _uid;
  final _churches = <Church>[];
  final _events = <ChurchEvent>[];
  final _categories = <String, List<EventCategory>>{};
  final _announcements = <String, List<Announcement>>{};
  final _memberships = <Membership>[];
  final _registrations = <Registration>[];
  Profile _profile = const Profile(id: 'demo-user', email: 'demo@evangelis.app', firstName: 'Marie', lastName: 'Kouassi');
  int _seq = 0;

  String _id() => 'demo-${_seq++}';

  void _seed() {
    const fr = 'fr';
    _churches.addAll(const [
      Church(
        id: 'c1',
        slug: 'ambassade-royaume',
        name: 'Église Ambassade du Royaume de Dieu',
        city: 'Abidjan',
        country: 'CI',
        defaultLocale: fr,
        joinMode: 'approval',
        branding: Branding(
          primaryColor: '#123B5C',
          accentColor: '#E0A526',
          tagline: I18nText({'fr': 'Ambassadeurs du Royaume', 'en': 'Ambassadors of the Kingdom'}),
          welcomeText: I18nText({
            'fr': 'Bienvenue dans la famille ! Cultes chaque dimanche à 9h.',
            'en': 'Welcome to the family! Services every Sunday at 9am.',
          }),
          aboutText: I18nText({'fr': 'Une église de quartier, fondée en 2019.', 'en': 'A neighbourhood church founded in 2019.'}),
          address: 'Cocody, Abidjan',
          email: 'contact@ambassade.example',
        ),
      ),
      Church(
        id: 'c2',
        slug: 'la-moisson',
        name: 'Église Baptiste La Moisson',
        city: 'Dakar',
        country: 'SN',
        defaultLocale: fr,
        joinMode: 'open',
        branding: Branding(
          primaryColor: '#1E4D2B',
          accentColor: '#D9A441',
          tagline: I18nText({'fr': 'La moisson est grande', 'en': 'The harvest is plentiful'}),
          welcomeText: I18nText({
            'fr': 'Enfants, jeunes, femmes et hommes : il y a une place pour vous.',
            'en': 'Children, youth, women and men: there is a place for you.',
          }),
          address: 'Sacré-Cœur 3, Dakar',
          phone: '+221 33 000 00 00',
          socials: {'youtube': 'https://youtube.com/@lamoisson'},
        ),
      ),
    ]);
    for (final c in _churches) {
      final cats = [
        EventCategory(id: '${c.id}-k1', name: const I18nText({'fr': 'Retraite', 'en': 'Retreat'})),
        EventCategory(id: '${c.id}-k2', name: const I18nText({'fr': 'Séminaire', 'en': 'Seminar'})),
        EventCategory(id: '${c.id}-k3', name: const I18nText({'fr': 'Jeunesse', 'en': 'Youth'})),
      ];
      _categories[c.id] = cats;
      _events.addAll([
        ChurchEvent(
          id: '${c.id}-e1',
          churchId: c.id,
          categoryId: cats[0].id,
          title: const I18nText({'fr': 'Retraite spirituelle', 'en': 'Spiritual retreat'}),
          description: const I18nText({
            'fr': 'Trois jours de prière, de louange et d\'enseignement.',
            'en': 'Three days of prayer, worship and teaching.',
          }),
          startsAt: _now.add(const Duration(days: 12, hours: 3)),
          endsAt: _now.add(const Duration(days: 14, hours: 3)),
          location: 'Centre de retraite',
          capacity: 3,
          maxSeatsPerRegistration: 2,
          registrationOpen: true,
          membersOnly: false,
        ),
        ChurchEvent(
          id: '${c.id}-e2',
          churchId: c.id,
          categoryId: cats[2].id,
          title: const I18nText({'fr': 'Soirée jeunesse', 'en': 'Youth night'}),
          startsAt: _now.add(const Duration(days: 4, hours: 5)),
          location: 'Salle polyvalente',
          registrationOpen: true,
          membersOnly: true,
        ),
        ChurchEvent(
          id: '${c.id}-e3',
          churchId: c.id,
          categoryId: cats[1].id,
          title: const I18nText({'fr': 'Séminaire des leaders', 'en': 'Leaders seminar'}),
          startsAt: _now.add(const Duration(days: 25)),
          location: 'Salle principale',
          capacity: 40,
          registrationOpen: false,
          membersOnly: false,
        ),
      ]);
      _announcements[c.id] = [
        Announcement(
          id: '${c.id}-a1',
          title: const I18nText({'fr': '72h de prière non-stop', 'en': '72 hours of non-stop prayer'}),
          body: const I18nText({
            'fr': 'Inscrivez-vous sur un créneau pour porter l\'église dans la prière.',
            'en': 'Sign up for a slot to carry the church in prayer.',
          }),
          publishAt: _now.subtract(const Duration(hours: 5)),
          membersOnly: false,
        ),
        Announcement(
          id: '${c.id}-a2',
          title: const I18nText({'fr': 'Réunion des ouvriers', 'en': 'Workers meeting'}),
          body: const I18nText({'fr': 'Samedi à 15h pour tous les départements.', 'en': 'Saturday 3pm for all departments.'}),
          publishAt: _now.subtract(const Duration(days: 2)),
          membersOnly: true,
        ),
      ];
    }
  }

  Future<T> _delay<T>(T value) => Future.value(value);

  bool _isActiveMember(String churchId) =>
      _memberships.any((m) => m.churchId == churchId && m.isActive);

  // ---------------------------------------------------------------- auth
  @override
  String? get currentUserId => _uid;

  @override
  Stream<String?> authChanges() => _auth.stream;

  @override
  Future<void> sendOtp(String email) async {
    if (!email.contains('@')) throw const AppError('Adresse e-mail invalide');
  }

  @override
  Future<void> verifyOtp(String email, String code) async {
    if (code.trim() != '123456') throw const AppError('Code incorrect (démo : 123456)');
    _uid = 'demo-user';
    _profile = Profile(id: _uid!, email: email, firstName: _profile.firstName, lastName: _profile.lastName);
    _auth.add(_uid);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _auth.add(null);
  }

  // ---------------------------------------------------------------- churches
  @override
  Future<List<ChurchSummary>> searchChurches(String query) {
    final q = query.trim().toLowerCase();
    return _delay([
      for (final c in _churches)
        if (q.isEmpty || c.name.toLowerCase().contains(q) || (c.city ?? '').toLowerCase().contains(q))
          ChurchSummary(id: c.id, slug: c.slug, name: c.name, city: c.city, country: c.country,
              primaryColor: c.branding.primaryColor),
    ]);
  }

  @override
  Future<Church?> churchBySlug(String slug) =>
      _delay(_churches.where((c) => c.slug == slug).firstOrNull);

  @override
  Future<Membership?> myMembership(String churchId) => _delay(_uid == null
      ? null
      : _memberships.where((m) => m.churchId == churchId && m.status != MembershipStatus.left).firstOrNull);

  @override
  Future<List<Membership>> myMemberships() => _delay(_uid == null ? <Membership>[] : List.of(_memberships));

  @override
  Future<Membership> joinChurch(String churchId, {String? inviteCode}) async {
    if (_uid == null) throw const AppError('authentication required');
    final existing = await myMembership(churchId);
    if (existing != null) return existing;
    final church = _churches.firstWhere((c) => c.id == churchId);
    final viaCode = (inviteCode ?? '').trim().isNotEmpty;
    if (church.joinMode == 'invite' && !viaCode) throw const AppError('invite code required');
    final m = Membership(
      id: _id(),
      churchId: churchId,
      role: 'member',
      // In the demo, approval is instant so the member area can be explored.
      status: MembershipStatus.active,
      churchName: church.name,
      churchSlug: church.slug,
    );
    _memberships.add(m);
    return m;
  }

  @override
  Future<void> leaveChurch(String churchId) async =>
      _memberships.removeWhere((m) => m.churchId == churchId);

  // ---------------------------------------------------------------- content
  @override
  Future<List<EventCategory>> categories(String churchId) => _delay(_categories[churchId] ?? []);

  @override
  Future<List<ChurchEvent>> upcomingEvents(String churchId) {
    final member = _isActiveMember(churchId);
    final list = _events.where((e) => e.churchId == churchId && (!e.membersOnly || member)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _delay(list);
  }

  @override
  Future<ChurchEvent?> event(String eventId) {
    final e = _events.where((e) => e.id == eventId).firstOrNull;
    if (e == null || (e.membersOnly && !_isActiveMember(e.churchId))) return _delay(null);
    return _delay(e);
  }

  @override
  Future<EventSeats?> seats(String eventId) {
    final e = _events.where((e) => e.id == eventId).firstOrNull;
    if (e == null) return _delay(null);
    final regs = _registrations.where((r) => r.eventId == eventId);
    return _delay(EventSeats(
      capacity: e.capacity,
      // Two seats are already taken by other members in the demo.
      confirmedSeats: 2 + regs.where((r) => r.status == RegistrationStatus.confirmed).fold(0, (a, r) => a + r.seats),
      waitlistCount: regs.where((r) => r.status == RegistrationStatus.waitlist).length,
    ));
  }

  @override
  Future<List<Announcement>> announcements(String churchId) {
    final member = _isActiveMember(churchId);
    return _delay([
      for (final a in _announcements[churchId] ?? <Announcement>[])
        if (!a.membersOnly || member) a,
    ]);
  }

  @override
  Future<Verse?> verseOfDay(String churchId, String locale) => _delay(locale == 'en'
      ? const Verse(reference: 'John 3:16', text: 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.')
      : const Verse(reference: 'Jean 3:16', text: 'Car Dieu a tant aimé le monde qu\'il a donné son Fils unique, afin que quiconque croit en lui ne périsse point, mais qu\'il ait la vie éternelle.'));

  // ---------------------------------------------------------------- registrations
  @override
  Future<Registration?> myRegistration(String eventId) => _delay(_uid == null
      ? null
      : _registrations.where((r) => r.eventId == eventId && r.status != RegistrationStatus.cancelled).firstOrNull);

  @override
  Future<List<Registration>> myRegistrations(String churchId) => _delay([
        for (final r in _registrations)
          if (r.status != RegistrationStatus.cancelled && r.event?.churchId == churchId) r,
      ]);

  @override
  Future<Registration> register(String eventId, int seats) async {
    final e = _events.firstWhere((e) => e.id == eventId);
    if (!_isActiveMember(e.churchId)) throw const AppError('members only');
    if (!e.canRegister) throw const AppError('registration closed');
    final existing = await myRegistration(eventId);
    if (existing != null) return existing;
    final s = (await this.seats(eventId))!;
    final fits = s.capacity == null || s.confirmedSeats + seats <= s.capacity!;
    final r = Registration(
      id: _id(),
      eventId: eventId,
      status: fits ? RegistrationStatus.confirmed : RegistrationStatus.waitlist,
      seats: seats,
      qrToken: 'demo-qr-${_seq++}',
      event: e,
    );
    _registrations.add(r);
    return r;
  }

  @override
  Future<void> cancelRegistration(String registrationId) async =>
      _registrations.removeWhere((r) => r.id == registrationId);

  // ---------------------------------------------------------------- profile
  @override
  Future<Profile?> myProfile() => _delay(_uid == null ? null : _profile);

  @override
  Future<void> updateProfile({String? firstName, String? lastName, String? phone, String? locale}) async {
    _profile = Profile(
      id: _profile.id,
      email: _profile.email,
      firstName: firstName ?? _profile.firstName,
      lastName: lastName ?? _profile.lastName,
      phone: phone ?? _profile.phone,
      locale: locale ?? _profile.locale,
    );
  }

  @override
  Future<Map<String, dynamic>> exportMyData() async => {
        'profile': {'email': _profile.email, 'first_name': _profile.firstName, 'last_name': _profile.lastName},
        'memberships': [for (final m in _memberships) {'church': m.churchName, 'status': m.status.name}],
        'event_registrations': _registrations.length,
      };

  @override
  Future<void> deleteMyData() async {
    _memberships.clear();
    _registrations.clear();
  }

  final feedbackSent = <String>[];

  @override
  Future<void> sendFeedback({String? churchId, required String kind, required String message, String? screen, String? platform}) async {
    if (_uid == null) throw const AppError('authentication required');
    if (message.trim().length < 3) throw const AppError('Message trop court');
    feedbackSent.add('$kind: ${message.trim()}');
  }

  @override
  Future<String> downloadBibleJson(String translation) =>
      (bibleLoader ?? (t) => rootBundle.loadString('assets/demo/bible_$t.json'))(translation);
}
