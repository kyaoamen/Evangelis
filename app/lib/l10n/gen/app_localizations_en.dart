// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Evangelis';

  @override
  String get findYourChurch => 'Find your church';

  @override
  String get findYourChurchHint => 'Church name or city';

  @override
  String get noChurchFound => 'No church found';

  @override
  String get myChurches => 'My churches';

  @override
  String get navHome => 'Home';

  @override
  String get navEvents => 'Events';

  @override
  String get navBible => 'Bible';

  @override
  String get navNews => 'News';

  @override
  String get navProfile => 'Profile';

  @override
  String get verseOfDay => 'Verse of the day';

  @override
  String get upcomingEvents => 'Upcoming events';

  @override
  String get latestAnnouncements => 'Latest announcements';

  @override
  String get seeAll => 'See all';

  @override
  String get noEvents => 'No upcoming events';

  @override
  String get noAnnouncements => 'No announcements yet';

  @override
  String get allCategories => 'All';

  @override
  String get searchEvents => 'Search events';

  @override
  String get membersOnly => 'Members only';

  @override
  String get register => 'Register';

  @override
  String get registered => 'Registration confirmed';

  @override
  String get waitlisted => 'On the waiting list';

  @override
  String get cancelRegistration => 'Cancel my registration';

  @override
  String get cancelRegistrationConfirm =>
      'Do you really want to cancel your registration?';

  @override
  String get seats => 'Seats';

  @override
  String seatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats left',
      one: '1 seat left',
      zero: 'Full',
    );
    return '$_temp0';
  }

  @override
  String get registrationClosed => 'Registration closed';

  @override
  String get showAtEntrance => 'Show this code at the entrance';

  @override
  String get joinToRegister => 'Join the church to register';

  @override
  String get joinChurch => 'Join the church';

  @override
  String get joinPending => 'Request sent. A leader will approve it.';

  @override
  String joinConsent(String church) {
    return 'I agree that $church keeps my member information. It reveals my religious affiliation and will only be used by the church.';
  }

  @override
  String get inviteCode => 'Invite code (optional)';

  @override
  String get inviteCodeRequired => 'Invite code';

  @override
  String get member => 'Member';

  @override
  String get pending => 'Waiting for approval';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email address';

  @override
  String get sendCode => 'Send me a code';

  @override
  String codeSentTo(String email) {
    return 'Code sent to $email';
  }

  @override
  String get verificationCode => '6-digit code';

  @override
  String get verify => 'Verify';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get phone => 'Phone';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get language => 'Language';

  @override
  String get aboutChurch => 'About the church';

  @override
  String get contact => 'Contact';

  @override
  String get switchChurch => 'Switch church';

  @override
  String get leaveChurch => 'Leave this church';

  @override
  String get myRegistrations => 'My registrations';

  @override
  String get privacy => 'Privacy';

  @override
  String get exportMyData => 'Export my data';

  @override
  String get deleteMyData => 'Delete my data';

  @override
  String get deleteMyDataConfirm =>
      'Your registrations and memberships will be deleted. Continue?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get bibleDownload => 'Download the Bible to read offline';

  @override
  String get bibleDownloading => 'Downloading…';

  @override
  String get bibleOffline => 'Available offline';

  @override
  String get bibleBooks => 'Books';

  @override
  String chapter(int n) {
    return 'Chapter $n';
  }

  @override
  String get visitorBanner => 'You are visiting this church';

  @override
  String get dataExported => 'Your data was copied';

  @override
  String get feedback => 'Give feedback';

  @override
  String get feedbackTitle => 'Help us improve Evangelis';

  @override
  String get feedbackBug => 'Problem';

  @override
  String get feedbackIdea => 'Idea';

  @override
  String get feedbackOther => 'Other';

  @override
  String get feedbackHint =>
      'Describe what went wrong or what you would like to see…';

  @override
  String get feedbackSend => 'Send';

  @override
  String get feedbackThanks => 'Thank you! Your feedback was sent.';

  @override
  String get feedbackSignIn => 'Sign in to send feedback.';

  @override
  String get joinSignInHint =>
      'Sign in with your email address to become a member. No password needed.';

  @override
  String get demoCodeHint => 'Demo version: the code is 123456.';
}
