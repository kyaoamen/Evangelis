-- Development seed: Bible metadata, a few verses, and one demo church.
-- Full Bible text is loaded with scripts/import_bible.mjs (public-domain LSG 1910 / KJV).

insert into public.bible_translations (code, name, locale, license) values
  ('LSG1910', 'Louis Segond 1910', 'fr', 'public-domain'),
  ('KJV', 'King James Version', 'en', 'public-domain')
on conflict do nothing;

insert into public.bible_books (translation, book, name, abbrev, chapters) values
  ('LSG1910', 19, 'Psaumes', 'Ps', 150), ('KJV', 19, 'Psalms', 'Ps', 150),
  ('LSG1910', 43, 'Jean', 'Jn', 21),     ('KJV', 43, 'John', 'Jn', 21)
on conflict do nothing;

insert into public.bible_verses (translation, book, chapter, verse, text) values
  ('LSG1910', 43, 3, 16, 'Car Dieu a tant aimé le monde qu''il a donné son Fils unique, afin que quiconque croit en lui ne périsse point, mais qu''il ait la vie éternelle.'),
  ('KJV', 43, 3, 16, 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.'),
  ('LSG1910', 19, 23, 1, 'Cantique de David. L''Éternel est mon berger: je ne manquerai de rien.'),
  ('KJV', 19, 23, 1, 'The LORD is my shepherd; I shall not want.')
on conflict do nothing;

-- Demo church (active) with no owner; sign up in the back-office and call
-- create_church() to get your own, or make yourself owner via SQL.
insert into public.churches (id, slug, name, city, country, default_locale, join_mode, status)
values ('11111111-1111-1111-1111-111111111111', 'eglise-demo', 'Église Démo', 'Paris', 'FR', 'fr', 'open', 'active')
on conflict do nothing;

insert into public.church_branding (church_id, primary_color, accent_color, tagline, welcome_text, address, email, socials)
values ('11111111-1111-1111-1111-111111111111', '#0F3D3E', '#D4A72C',
        '{"fr": "Une famille pour grandir dans la foi", "en": "A family to grow in faith"}',
        '{"fr": "Bienvenue ! Venez comme vous êtes.", "en": "Welcome! Come as you are."}',
        '1 rue de la Paix, 75002 Paris', 'contact@eglise-demo.example', '{"youtube": "https://youtube.com/@example"}')
on conflict do nothing;

insert into public.event_categories (id, church_id, name, sort) values
  ('22222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '{"fr": "Retraite", "en": "Retreat"}', 1),
  ('22222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', '{"fr": "Séminaire", "en": "Seminar"}', 2),
  ('22222222-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', '{"fr": "Baptême", "en": "Baptism"}', 3)
on conflict do nothing;

insert into public.events (church_id, category_id, title, description, starts_at, ends_at, location, capacity, registration_open, visibility, published_at)
values
  ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000001',
   '{"fr": "Retraite spirituelle", "en": "Spiritual retreat"}',
   '{"fr": "Trois jours de prière et de louange.", "en": "Three days of prayer and worship."}',
   now() + interval '30 days', now() + interval '32 days', 'Centre de retraite, Chartres', 120, true, 'public', now()),
  ('11111111-1111-1111-1111-111111111111', '22222222-0000-0000-0000-000000000002',
   '{"fr": "Séminaire des leaders", "en": "Leaders seminar"}', null,
   now() + interval '10 days', null, 'Salle principale', 40, true, 'members', now());

insert into public.announcements (church_id, title, body, audience) values
  ('11111111-1111-1111-1111-111111111111',
   '{"fr": "Culte de dimanche à 10h30", "en": "Sunday service at 10:30"}',
   '{"fr": "Rejoignez-nous ce dimanche pour un temps de louange.", "en": "Join us this Sunday for worship."}', 'all');
