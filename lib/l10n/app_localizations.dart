import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('es'),
    Locale('hi'),
    Locale('ja'),
    Locale('pt'),
  ];

  /// Title of the application
  ///
  /// In en, this message translates to:
  /// **'Pixel Art'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navGallery.
  ///
  /// In en, this message translates to:
  /// **'My Works'**
  String get navGallery;

  /// No description provided for @navCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get navCamera;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search artworks...'**
  String get searchHint;

  /// No description provided for @categoriesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoriesAll;

  /// No description provided for @categoriesEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get categoriesEasy;

  /// No description provided for @categoriesMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get categoriesMedium;

  /// No description provided for @categoriesHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get categoriesHard;

  /// No description provided for @dailyArt.
  ///
  /// In en, this message translates to:
  /// **'Daily Art'**
  String get dailyArt;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffects;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Vibration & Haptics'**
  String get hapticFeedback;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Write Review'**
  String get rateUs;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @magicWand.
  ///
  /// In en, this message translates to:
  /// **'Magic Wand'**
  String get magicWand;

  /// No description provided for @colorSplash.
  ///
  /// In en, this message translates to:
  /// **'Color Splash'**
  String get colorSplash;

  /// No description provided for @magnifier.
  ///
  /// In en, this message translates to:
  /// **'Magnifier'**
  String get magnifier;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select a Color'**
  String get selectColor;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great Job!'**
  String get greatJob;

  /// No description provided for @artworkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Artwork Completed!'**
  String get artworkCompleted;

  /// No description provided for @shareReplay.
  ///
  /// In en, this message translates to:
  /// **'Share Replay'**
  String get shareReplay;

  /// No description provided for @continueColoring.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueColoring;

  /// No description provided for @getPlus.
  ///
  /// In en, this message translates to:
  /// **'Get Pixely Plus'**
  String get getPlus;

  /// No description provided for @removeAds.
  ///
  /// In en, this message translates to:
  /// **'Remove Ads & Unlock All'**
  String get removeAds;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @subscribeNow.
  ///
  /// In en, this message translates to:
  /// **'Subscribe Now'**
  String get subscribeNow;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @diamonds.
  ///
  /// In en, this message translates to:
  /// **'Diamonds'**
  String get diamonds;

  /// No description provided for @claimDailyReward.
  ///
  /// In en, this message translates to:
  /// **'Claim Daily Reward'**
  String get claimDailyReward;

  /// No description provided for @watchAdForReward.
  ///
  /// In en, this message translates to:
  /// **'Watch Ad'**
  String get watchAdForReward;

  /// No description provided for @importPhoto.
  ///
  /// In en, this message translates to:
  /// **'Import Photo'**
  String get importPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @pixelate.
  ///
  /// In en, this message translates to:
  /// **'Pixelate'**
  String get pixelate;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @gridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid Size'**
  String get gridSize;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @jumpBackIn.
  ///
  /// In en, this message translates to:
  /// **'Jump back in'**
  String get jumpBackIn;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @dailyPixel.
  ///
  /// In en, this message translates to:
  /// **'Daily Pixel'**
  String get dailyPixel;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get dayStreak;

  /// No description provided for @streakLost.
  ///
  /// In en, this message translates to:
  /// **'STREAK LOST • REPAIR WITHIN 48H'**
  String get streakLost;

  /// No description provided for @restoreStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore {days}-Day Streak!'**
  String restoreStreakTitle(int days);

  /// No description provided for @restoreStreakSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to restore with 300 💎 or 1 Ad'**
  String get restoreStreakSubtitle;

  /// No description provided for @streakFreeze.
  ///
  /// In en, this message translates to:
  /// **'Streak Freeze'**
  String get streakFreeze;

  /// No description provided for @streakFreezeEquipped.
  ///
  /// In en, this message translates to:
  /// **'Streak Freeze equipped! 🧊'**
  String get streakFreezeEquipped;

  /// No description provided for @maxFreezesHeld.
  ///
  /// In en, this message translates to:
  /// **'Maximum freezes held! (2/2)'**
  String get maxFreezesHeld;

  /// No description provided for @notEnoughDiamonds.
  ///
  /// In en, this message translates to:
  /// **'Not enough diamonds ({count} 💎 needed)'**
  String notEnoughDiamonds(int count);

  /// No description provided for @freeAd.
  ///
  /// In en, this message translates to:
  /// **'1 Free Ad'**
  String get freeAd;

  /// No description provided for @repair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get repair;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @shelves.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get shelves;

  /// No description provided for @fullGrid.
  ///
  /// In en, this message translates to:
  /// **'Full Grid'**
  String get fullGrid;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get notStarted;

  /// No description provided for @noArtworksFound.
  ///
  /// In en, this message translates to:
  /// **'No artworks found'**
  String get noArtworksFound;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters'**
  String get tryAnotherSearch;

  /// No description provided for @mysteryGift.
  ///
  /// In en, this message translates to:
  /// **'Mystery Diamond Gift'**
  String get mysteryGift;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @premiumArtwork.
  ///
  /// In en, this message translates to:
  /// **'Premium Artwork'**
  String get premiumArtwork;

  /// No description provided for @unlockThisOne.
  ///
  /// In en, this message translates to:
  /// **'Unlock this one'**
  String get unlockThisOne;

  /// No description provided for @tryWithAd.
  ///
  /// In en, this message translates to:
  /// **'Try with Ad'**
  String get tryWithAd;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @noAdAvailable.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now — try again later.'**
  String get noAdAvailable;

  /// No description provided for @sortDefault.
  ///
  /// In en, this message translates to:
  /// **'Sort: Default'**
  String get sortDefault;

  /// No description provided for @sortEasyFirst.
  ///
  /// In en, this message translates to:
  /// **'Easy First'**
  String get sortEasyFirst;

  /// No description provided for @sortHardFirst.
  ///
  /// In en, this message translates to:
  /// **'Hard First'**
  String get sortHardFirst;

  /// No description provided for @sortFewColors.
  ///
  /// In en, this message translates to:
  /// **'Few Colors'**
  String get sortFewColors;

  /// No description provided for @sortManyColors.
  ///
  /// In en, this message translates to:
  /// **'Many Colors'**
  String get sortManyColors;

  /// No description provided for @exitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaving So Soon?'**
  String get exitDialogTitle;

  /// No description provided for @exitDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Before you go, check out our other relaxing games or keep coloring!'**
  String get exitDialogMessage;

  /// No description provided for @exitDialogKeepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep Playing'**
  String get exitDialogKeepPlaying;

  /// No description provided for @exitDialogExit.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitDialogExit;

  /// No description provided for @emptyGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Canvas is Empty'**
  String get emptyGalleryTitle;

  /// No description provided for @emptyGalleryMessage.
  ///
  /// In en, this message translates to:
  /// **'Color artworks from the catalog to build your personal gallery collection!'**
  String get emptyGalleryMessage;

  /// No description provided for @startFirstArtwork.
  ///
  /// In en, this message translates to:
  /// **'Start Your First Artwork 🎨'**
  String get startFirstArtwork;

  /// No description provided for @deleteArtwork.
  ///
  /// In en, this message translates to:
  /// **'Delete Artwork'**
  String get deleteArtwork;

  /// No description provided for @deleteArtworkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get deleteArtworkConfirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);
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
      <String>['en', 'es', 'hi', 'ja', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
