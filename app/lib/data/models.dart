/// Translatable text stored as jsonb `{"fr": "...", "en": "..."}`.
class I18nText {
  const I18nText(this.values);
  final Map<String, String> values;

  static I18nText? fromJson(Object? json) {
    if (json is! Map) return null;
    return I18nText({
      for (final e in json.entries)
        if (e.value is String) e.key.toString(): e.value as String,
    });
  }

  /// Text in [locale], else the church default, else any value.
  String of(String locale, {String fallback = 'fr'}) =>
      values[locale] ?? values[fallback] ?? (values.isEmpty ? '' : values.values.first);
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

class ChurchSummary {
  const ChurchSummary({
    required this.id,
    required this.slug,
    required this.name,
    this.city,
    this.country,
    this.logoUrl,
    this.primaryColor,
  });
  final String id, slug, name;
  final String? city, country, logoUrl, primaryColor;

  factory ChurchSummary.fromJson(Map<String, dynamic> j) => ChurchSummary(
        id: j['id'],
        slug: j['slug'],
        name: j['name'],
        city: j['city'],
        country: j['country'],
        logoUrl: j['logo_url'],
        primaryColor: j['primary_color'],
      );
}

class Church {
  const Church({
    required this.id,
    required this.slug,
    required this.name,
    required this.defaultLocale,
    required this.joinMode,
    required this.branding,
    this.city,
    this.country,
  });
  final String id, slug, name, defaultLocale, joinMode;
  final String? city, country;
  final Branding branding;

  factory Church.fromJson(Map<String, dynamic> j) => Church(
        id: j['id'],
        slug: j['slug'],
        name: j['name'],
        city: j['city'],
        country: j['country'],
        defaultLocale: j['default_locale'] ?? 'fr',
        joinMode: j['join_mode'] ?? 'approval',
        branding: Branding.fromJson((j['church_branding'] as Map<String, dynamic>?) ?? const {}),
      );
}

class Branding {
  const Branding({
    this.logoUrl,
    this.coverUrl,
    this.primaryColor = '#0F3D3E',
    this.accentColor = '#D4A72C',
    this.tagline,
    this.welcomeText,
    this.aboutText,
    this.featuredVideoUrl,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.socials = const {},
  });
  final String? logoUrl, coverUrl, featuredVideoUrl, address, phone, email, website;
  final String primaryColor, accentColor;
  final I18nText? tagline, welcomeText, aboutText;
  final Map<String, String> socials;

  factory Branding.fromJson(Map<String, dynamic> j) => Branding(
        logoUrl: j['logo_url'],
        coverUrl: j['cover_url'],
        primaryColor: j['primary_color'] ?? '#0F3D3E',
        accentColor: j['accent_color'] ?? '#D4A72C',
        tagline: I18nText.fromJson(j['tagline']),
        welcomeText: I18nText.fromJson(j['welcome_text']),
        aboutText: I18nText.fromJson(j['about_text']),
        featuredVideoUrl: j['featured_video_url'],
        address: j['address'],
        phone: j['phone'],
        email: j['email'],
        website: j['website'],
        socials: {
          for (final e in ((j['socials'] as Map?) ?? const {}).entries)
            if (e.value is String && (e.value as String).isNotEmpty) e.key.toString(): e.value as String,
        },
      );
}

enum MembershipStatus { pending, active, suspended, left }

class Membership {
  const Membership({
    required this.id,
    required this.churchId,
    required this.role,
    required this.status,
    this.churchName,
    this.churchSlug,
  });
  final String id, churchId, role;
  final MembershipStatus status;
  final String? churchName, churchSlug;

  bool get isActive => status == MembershipStatus.active;

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'],
        churchId: j['church_id'],
        role: j['role'],
        status: MembershipStatus.values.byName(j['status']),
        churchName: (j['churches'] as Map?)?['name'],
        churchSlug: (j['churches'] as Map?)?['slug'],
      );
}

class EventCategory {
  const EventCategory({required this.id, required this.name});
  final String id;
  final I18nText name;

  factory EventCategory.fromJson(Map<String, dynamic> j) =>
      EventCategory(id: j['id'], name: I18nText.fromJson(j['name'])!);
}

class ChurchEvent {
  const ChurchEvent({
    required this.id,
    required this.churchId,
    required this.title,
    required this.startsAt,
    required this.registrationOpen,
    required this.membersOnly,
    this.categoryId,
    this.description,
    this.posterUrl,
    this.endsAt,
    this.location,
    this.capacity,
    this.maxSeatsPerRegistration = 1,
  });
  final String id, churchId;
  final String? categoryId, posterUrl, location;
  final I18nText title;
  final I18nText? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? capacity;
  final int maxSeatsPerRegistration;
  final bool registrationOpen, membersOnly;

  bool get canRegister => registrationOpen && startsAt.isAfter(DateTime.now());

  factory ChurchEvent.fromJson(Map<String, dynamic> j) => ChurchEvent(
        id: j['id'],
        churchId: j['church_id'],
        categoryId: j['category_id'],
        title: I18nText.fromJson(j['title'])!,
        description: I18nText.fromJson(j['description']),
        posterUrl: j['poster_url'],
        startsAt: _date(j['starts_at'])!,
        endsAt: _date(j['ends_at']),
        location: j['location'],
        capacity: j['capacity'],
        maxSeatsPerRegistration: j['max_seats_per_registration'] ?? 1,
        registrationOpen: j['registration_open'] ?? false,
        membersOnly: j['visibility'] == 'members',
      );
}

class EventSeats {
  const EventSeats({this.capacity, required this.confirmedSeats, required this.waitlistCount});
  final int? capacity;
  final int confirmedSeats, waitlistCount;
  int? get left => capacity == null ? null : (capacity! - confirmedSeats).clamp(0, capacity!);

  factory EventSeats.fromJson(Map<String, dynamic> j) => EventSeats(
        capacity: j['capacity'],
        confirmedSeats: j['confirmed_seats'] ?? 0,
        waitlistCount: j['waitlist_count'] ?? 0,
      );
}

enum RegistrationStatus { confirmed, waitlist, cancelled }

class Registration {
  const Registration({
    required this.id,
    required this.eventId,
    required this.status,
    required this.seats,
    required this.qrToken,
    this.event,
  });
  final String id, eventId, qrToken;
  final RegistrationStatus status;
  final int seats;
  final ChurchEvent? event;

  factory Registration.fromJson(Map<String, dynamic> j) => Registration(
        id: j['id'],
        eventId: j['event_id'],
        status: RegistrationStatus.values.byName(j['status']),
        seats: j['seats'] ?? 1,
        qrToken: j['qr_token'],
        event: j['events'] is Map ? ChurchEvent.fromJson(Map<String, dynamic>.from(j['events'])) : null,
      );
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishAt,
    required this.membersOnly,
    this.imageUrl,
  });
  final String id;
  final I18nText title, body;
  final DateTime publishAt;
  final bool membersOnly;
  final String? imageUrl;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'],
        title: I18nText.fromJson(j['title'])!,
        body: I18nText.fromJson(j['body'])!,
        publishAt: _date(j['publish_at'])!,
        membersOnly: j['audience'] == 'members',
        imageUrl: j['image_url'],
      );
}

class Verse {
  const Verse({required this.reference, required this.text});
  final String reference, text;
}

class Profile {
  const Profile({required this.id, this.email, this.firstName, this.lastName, this.phone, this.locale = 'fr'});
  final String id;
  final String? email, firstName, lastName, phone;
  final String locale;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'],
        email: j['email'],
        firstName: j['first_name'],
        lastName: j['last_name'],
        phone: j['phone'],
        locale: j['locale'] ?? 'fr',
      );
}

/// An offline Bible: books -> chapters -> verses.
class BibleBook {
  const BibleBook({required this.number, required this.name, required this.chapters});
  final int number;
  final String name;
  final List<List<String>> chapters;
}

class Bible {
  const Bible({required this.code, required this.name, required this.books});
  final String code, name;
  final List<BibleBook> books;

  factory Bible.fromJson(Map<String, dynamic> j) => Bible(
        code: j['code'],
        name: j['name'],
        books: [
          for (final b in j['books'] as List)
            BibleBook(
              number: b['n'],
              name: b['name'],
              chapters: [for (final c in b['chapters'] as List) List<String>.from(c)],
            ),
        ],
      );
}

class AppError implements Exception {
  const AppError(this.message);
  final String message;
  @override
  String toString() => message;
}
