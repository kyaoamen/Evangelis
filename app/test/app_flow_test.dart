import 'package:church_app/app.dart';
import 'package:church_app/data/demo_repository.dart';
import 'package:church_app/services/bible_store.dart';
import 'package:church_app/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bibleJson =
    '{"code":"LSG1910","name":"Demo","books":[{"n":43,"name":"Jean (extrait)","chapters":[["Verset de test."]]}]}';

Future<DemoRepository> _pump(WidgetTester tester, {Map<String, Object> prefs = const {'locale': 'fr'}}) async {
  await initializeDateFormatting('fr');
  await initializeDateFormatting('en');
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final repo = DemoRepository(bibleLoader: (_) async => _bibleJson);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      prefsProvider.overrideWithValue(sp),
      bibleStoreProvider.overrideWithValue(MemoryBibleStore()),
    ],
    child: const EvangelisApp(),
  ));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('email')), 'marie@example.com');
  await tester.tap(find.byKey(const Key('send-code')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('code')), '123456');
  await tester.tap(find.byKey(const Key('verify')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('visitor finds a church, signs in, joins and registers for an event', (tester) async {
    await _pump(tester);

    // Church search lists both pilot churches; search filters by city.
    expect(find.text('Trouvez votre église'), findsOneWidget);
    expect(find.text('Église Baptiste La Moisson'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('church-search')), 'dakar');
    await tester.pumpAndSettle();
    expect(find.text('Église Ambassade du Royaume de Dieu'), findsNothing);
    await tester.tap(find.text('Église Baptiste La Moisson'));
    await tester.pumpAndSettle();

    // Visitor view: public content, a join banner, the verse of the day.
    expect(find.text('Vous visitez cette église'), findsOneWidget);
    expect(find.textContaining('Jean 3:16'), findsOneWidget);
    expect(find.text('Soirée jeunesse'), findsNothing); // members-only event hidden

    // Join -> sign in -> consent -> member.
    await tester.tap(find.byKey(const Key('join-banner')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    await _signIn(tester);
    expect(find.byKey(const Key('consent')), findsOneWidget);
    await tester.tap(find.byKey(const Key('consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Vous visitez cette église'), findsNothing);
    expect(find.text('Soirée jeunesse'), findsOneWidget); // members-only now visible

    // Events tab -> event detail -> register.
    await tester.tap(find.text('Événements').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retraite spirituelle'));
    await tester.pumpAndSettle();
    expect(find.text('1 place restante'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('register')));
    expect(find.text('Inscription confirmée'), findsOneWidget);
    expect(find.text('Présentez ce code à l\'entrée'), findsOneWidget);
  });

  testWidgets('member sends feedback from the church space', (tester) async {
    final repo = await _pump(tester, prefs: {'locale': 'fr', 'active_church_slug': 'la-moisson'});
    expect(find.text('Église Baptiste La Moisson'), findsWidgets);

    // Signed out: the sheet asks to sign in first.
    await tester.tap(find.byKey(const Key('feedback-button')));
    await tester.pumpAndSettle();
    expect(find.text('Connectez-vous pour envoyer votre avis.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    await _signIn(tester);

    await tester.tap(find.byKey(const Key('feedback-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Problème'));
    await tester.enterText(find.byKey(const Key('feedback-text')), 'Le bouton retour est trop petit');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feedback-send')));
    await tester.pumpAndSettle();
    expect(find.text('Merci ! Votre avis a été envoyé.'), findsOneWidget);
    expect(repo.feedbackSent, ['bug: Le bouton retour est trop petit']);
  });

  testWidgets('language toggle switches the UI to English', (tester) async {
    await _pump(tester);
    expect(find.text('Trouvez votre église'), findsOneWidget);
    await tester.tap(find.byKey(const Key('language-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Find your church'), findsOneWidget);
  });

  testWidgets('Bible downloads once and reads offline', (tester) async {
    await _pump(tester, prefs: {'locale': 'fr', 'active_church_slug': 'ambassade-royaume'});
    await tester.tap(find.text('Bible').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bible-download')));
    await tester.pumpAndSettle();
    expect(find.text('Disponible hors ligne'), findsOneWidget);
    await tester.tap(find.text('Jean (extrait)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Verset de test.', findRichText: true), findsOneWidget);
  });
}
