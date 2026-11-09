import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Evangelis'**
  String get appName;

  /// No description provided for @findYourChurch.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez votre église'**
  String get findYourChurch;

  /// No description provided for @findYourChurchHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'église ou ville'**
  String get findYourChurchHint;

  /// No description provided for @noChurchFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune église trouvée'**
  String get noChurchFound;

  /// No description provided for @myChurches.
  ///
  /// In fr, this message translates to:
  /// **'Mes églises'**
  String get myChurches;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get navEvents;

  /// No description provided for @navBible.
  ///
  /// In fr, this message translates to:
  /// **'Bible'**
  String get navBible;

  /// No description provided for @navNews.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get navNews;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @verseOfDay.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour'**
  String get verseOfDay;

  /// No description provided for @upcomingEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements à venir'**
  String get upcomingEvents;

  /// No description provided for @latestAnnouncements.
  ///
  /// In fr, this message translates to:
  /// **'Dernières annonces'**
  String get latestAnnouncements;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get seeAll;

  /// No description provided for @noEvents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement à venir'**
  String get noEvents;

  /// No description provided for @noAnnouncements.
  ///
  /// In fr, this message translates to:
  /// **'Aucune annonce pour le moment'**
  String get noAnnouncements;

  /// No description provided for @allCategories.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allCategories;

  /// No description provided for @searchEvents.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un événement'**
  String get searchEvents;

  /// No description provided for @membersOnly.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux membres'**
  String get membersOnly;

  /// No description provided for @register.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get register;

  /// No description provided for @registered.
  ///
  /// In fr, this message translates to:
  /// **'Inscription confirmée'**
  String get registered;

  /// No description provided for @waitlisted.
  ///
  /// In fr, this message translates to:
  /// **'Sur liste d\'attente'**
  String get waitlisted;

  /// No description provided for @cancelRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Annuler mon inscription'**
  String get cancelRegistration;

  /// No description provided for @cancelRegistrationConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment annuler votre inscription ?'**
  String get cancelRegistrationConfirm;

  /// No description provided for @seats.
  ///
  /// In fr, this message translates to:
  /// **'Places'**
  String get seats;

  /// No description provided for @seatsLeft.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Complet} =1{1 place restante} other{{count} places restantes}}'**
  String seatsLeft(int count);

  /// No description provided for @registrationClosed.
  ///
  /// In fr, this message translates to:
  /// **'Inscriptions fermées'**
  String get registrationClosed;

  /// No description provided for @showAtEntrance.
  ///
  /// In fr, this message translates to:
  /// **'Présentez ce code à l\'entrée'**
  String get showAtEntrance;

  /// No description provided for @joinToRegister.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez l\'église pour vous inscrire'**
  String get joinToRegister;

  /// No description provided for @joinChurch.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre l\'église'**
  String get joinChurch;

  /// No description provided for @joinPending.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée. Un responsable va la valider.'**
  String get joinPending;

  /// No description provided for @joinConsent.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte que {church} conserve mes informations de membre. Elles révèlent mon appartenance religieuse et ne seront utilisées que par l\'église.'**
  String joinConsent(String church);

  /// No description provided for @inviteCode.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation (facultatif)'**
  String get inviteCode;

  /// No description provided for @inviteCodeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get inviteCodeRequired;

  /// No description provided for @member.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get member;

  /// No description provided for @pending.
  ///
  /// In fr, this message translates to:
  /// **'En attente de validation'**
  String get pending;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get email;

  /// No description provided for @sendCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un code'**
  String get sendCode;

  /// No description provided for @codeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé à {email}'**
  String codeSentTo(String email);

  /// No description provided for @verificationCode.
  ///
  /// In fr, this message translates to:
  /// **'Code à 6 chiffres'**
  String get verificationCode;

  /// No description provided for @verify.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get verify;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré'**
  String get saved;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @aboutChurch.
  ///
  /// In fr, this message translates to:
  /// **'À propos de l\'église'**
  String get aboutChurch;

  /// No description provided for @contact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @switchChurch.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'église'**
  String get switchChurch;

  /// No description provided for @leaveChurch.
  ///
  /// In fr, this message translates to:
  /// **'Quitter cette église'**
  String get leaveChurch;

  /// No description provided for @myRegistrations.
  ///
  /// In fr, this message translates to:
  /// **'Mes inscriptions'**
  String get myRegistrations;

  /// No description provided for @privacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacy;

  /// No description provided for @exportMyData.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get exportMyData;

  /// No description provided for @deleteMyData.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mes données'**
  String get deleteMyData;

  /// No description provided for @deleteMyDataConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Vos inscriptions et adhésions seront supprimées. Continuer ?'**
  String get deleteMyDataConfirm;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @bibleDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger la Bible pour la lire hors ligne'**
  String get bibleDownload;

  /// No description provided for @bibleDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement…'**
  String get bibleDownloading;

  /// No description provided for @bibleOffline.
  ///
  /// In fr, this message translates to:
  /// **'Disponible hors ligne'**
  String get bibleOffline;

  /// No description provided for @bibleBooks.
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get bibleBooks;

  /// No description provided for @chapter.
  ///
  /// In fr, this message translates to:
  /// **'Chapitre {n}'**
  String chapter(int n);

  /// No description provided for @visitorBanner.
  ///
  /// In fr, this message translates to:
  /// **'Vous visitez cette église'**
  String get visitorBanner;

  /// No description provided for @dataExported.
  ///
  /// In fr, this message translates to:
  /// **'Vos données ont été copiées'**
  String get dataExported;

  /// No description provided for @feedback.
  ///
  /// In fr, this message translates to:
  /// **'Donner mon avis'**
  String get feedback;

  /// No description provided for @feedbackTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aidez-nous à améliorer Evangelis'**
  String get feedbackTitle;

  /// No description provided for @feedbackBug.
  ///
  /// In fr, this message translates to:
  /// **'Problème'**
  String get feedbackBug;

  /// No description provided for @feedbackIdea.
  ///
  /// In fr, this message translates to:
  /// **'Idée'**
  String get feedbackIdea;

  /// No description provided for @feedbackOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get feedbackOther;

  /// No description provided for @feedbackHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez ce qui ne va pas ou ce que vous aimeriez voir…'**
  String get feedbackHint;

  /// No description provided for @feedbackSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get feedbackSend;

  /// No description provided for @feedbackThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci ! Votre avis a été envoyé.'**
  String get feedbackThanks;

  /// No description provided for @feedbackSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour envoyer votre avis.'**
  String get feedbackSignIn;

  /// No description provided for @joinSignInHint.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec votre adresse e-mail pour devenir membre. Aucun mot de passe n\'est nécessaire.'**
  String get joinSignInHint;

  /// No description provided for @demoCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Version de démonstration : le code est 123456.'**
  String get demoCodeHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
