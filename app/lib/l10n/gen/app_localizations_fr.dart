// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Evangelis';

  @override
  String get findYourChurch => 'Trouvez votre église';

  @override
  String get findYourChurchHint => 'Nom de l\'église ou ville';

  @override
  String get noChurchFound => 'Aucune église trouvée';

  @override
  String get myChurches => 'Mes églises';

  @override
  String get navHome => 'Accueil';

  @override
  String get navEvents => 'Événements';

  @override
  String get navBible => 'Bible';

  @override
  String get navNews => 'Annonces';

  @override
  String get navProfile => 'Profil';

  @override
  String get verseOfDay => 'Verset du jour';

  @override
  String get upcomingEvents => 'Événements à venir';

  @override
  String get latestAnnouncements => 'Dernières annonces';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get noEvents => 'Aucun événement à venir';

  @override
  String get noAnnouncements => 'Aucune annonce pour le moment';

  @override
  String get allCategories => 'Tous';

  @override
  String get searchEvents => 'Rechercher un événement';

  @override
  String get membersOnly => 'Réservé aux membres';

  @override
  String get register => 'S\'inscrire';

  @override
  String get registered => 'Inscription confirmée';

  @override
  String get waitlisted => 'Sur liste d\'attente';

  @override
  String get cancelRegistration => 'Annuler mon inscription';

  @override
  String get cancelRegistrationConfirm =>
      'Voulez-vous vraiment annuler votre inscription ?';

  @override
  String get seats => 'Places';

  @override
  String seatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places restantes',
      one: '1 place restante',
      zero: 'Complet',
    );
    return '$_temp0';
  }

  @override
  String get registrationClosed => 'Inscriptions fermées';

  @override
  String get showAtEntrance => 'Présentez ce code à l\'entrée';

  @override
  String get joinToRegister => 'Rejoignez l\'église pour vous inscrire';

  @override
  String get joinChurch => 'Rejoindre l\'église';

  @override
  String get joinPending => 'Demande envoyée. Un responsable va la valider.';

  @override
  String joinConsent(String church) {
    return 'J\'accepte que $church conserve mes informations de membre. Elles révèlent mon appartenance religieuse et ne seront utilisées que par l\'église.';
  }

  @override
  String get inviteCode => 'Code d\'invitation (facultatif)';

  @override
  String get inviteCodeRequired => 'Code d\'invitation';

  @override
  String get member => 'Membre';

  @override
  String get pending => 'En attente de validation';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get email => 'Adresse e-mail';

  @override
  String get sendCode => 'Recevoir un code';

  @override
  String codeSentTo(String email) {
    return 'Code envoyé à $email';
  }

  @override
  String get verificationCode => 'Code à 6 chiffres';

  @override
  String get verify => 'Valider';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get phone => 'Téléphone';

  @override
  String get save => 'Enregistrer';

  @override
  String get saved => 'Enregistré';

  @override
  String get language => 'Langue';

  @override
  String get aboutChurch => 'À propos de l\'église';

  @override
  String get contact => 'Contact';

  @override
  String get switchChurch => 'Changer d\'église';

  @override
  String get leaveChurch => 'Quitter cette église';

  @override
  String get myRegistrations => 'Mes inscriptions';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get exportMyData => 'Exporter mes données';

  @override
  String get deleteMyData => 'Supprimer mes données';

  @override
  String get deleteMyDataConfirm =>
      'Vos inscriptions et adhésions seront supprimées. Continuer ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get errorGeneric => 'Une erreur est survenue. Réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get bibleDownload => 'Télécharger la Bible pour la lire hors ligne';

  @override
  String get bibleDownloading => 'Téléchargement…';

  @override
  String get bibleOffline => 'Disponible hors ligne';

  @override
  String get bibleBooks => 'Livres';

  @override
  String chapter(int n) {
    return 'Chapitre $n';
  }

  @override
  String get visitorBanner => 'Vous visitez cette église';

  @override
  String get dataExported => 'Vos données ont été copiées';

  @override
  String get feedback => 'Donner mon avis';

  @override
  String get feedbackTitle => 'Aidez-nous à améliorer Evangelis';

  @override
  String get feedbackBug => 'Problème';

  @override
  String get feedbackIdea => 'Idée';

  @override
  String get feedbackOther => 'Autre';

  @override
  String get feedbackHint =>
      'Décrivez ce qui ne va pas ou ce que vous aimeriez voir…';

  @override
  String get feedbackSend => 'Envoyer';

  @override
  String get feedbackThanks => 'Merci ! Votre avis a été envoyé.';

  @override
  String get feedbackSignIn => 'Connectez-vous pour envoyer votre avis.';

  @override
  String get joinSignInHint =>
      'Connectez-vous avec votre adresse e-mail pour devenir membre. Aucun mot de passe n\'est nécessaire.';

  @override
  String get demoCodeHint => 'Version de démonstration : le code est 123456.';
}
