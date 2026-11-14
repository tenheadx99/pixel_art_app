// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pixel Art';

  @override
  String get navHome => 'Home';

  @override
  String get navGallery => 'My Works';

  @override
  String get navCamera => 'Camera';

  @override
  String get navProfile => 'Profile';

  @override
  String get searchHint => 'Search artworks...';

  @override
  String get categoriesAll => 'All';

  @override
  String get categoriesEasy => 'Easy';

  @override
  String get categoriesMedium => 'Medium';

  @override
  String get categoriesHard => 'Hard';

  @override
  String get dailyArt => 'Daily Art';

  @override
  String get completed => 'Completed';

  @override
  String get inProgress => 'In Progress';

  @override
  String get settings => 'Settings';

  @override
  String get soundEffects => 'Sound Effects';

  @override
  String get hapticFeedback => 'Vibration & Haptics';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get rateUs => 'Write Review';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get version => 'Version';

  @override
  String get magicWand => 'Magic Wand';

  @override
  String get colorSplash => 'Color Splash';

  @override
  String get magnifier => 'Magnifier';

  @override
  String get selectColor => 'Select a Color';

  @override
  String get greatJob => 'Great Job!';

  @override
  String get artworkCompleted => 'Artwork Completed!';

  @override
  String get shareReplay => 'Share Replay';

  @override
  String get continueColoring => 'Continue';

  @override
  String get getPlus => 'Get Pixely Plus';

  @override
  String get removeAds => 'Remove Ads & Unlock All';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get subscribeNow => 'Subscribe Now';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get diamonds => 'Diamonds';

  @override
  String get claimDailyReward => 'Claim Daily Reward';

  @override
  String get watchAdForReward => 'Watch Ad';

  @override
  String get importPhoto => 'Import Photo';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get pixelate => 'Pixelate';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get gridSize => 'Grid Size';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get ok => 'OK';

  @override
  String get jumpBackIn => 'Jump back in';

  @override
  String get resume => 'Resume';

  @override
  String get play => 'Play';

  @override
  String get dailyPixel => 'Daily Pixel';

  @override
  String get streak => 'Streak';

  @override
  String get dayStreak => 'Day Streak';

  @override
  String get streakLost => 'STREAK LOST • REPAIR WITHIN 48H';

  @override
  String restoreStreakTitle(int days) {
    return 'Restore $days-Day Streak!';
  }

  @override
  String get restoreStreakSubtitle => 'Tap to restore with 300 💎 or 1 Ad';

  @override
  String get streakFreeze => 'Streak Freeze';

  @override
  String get streakFreezeEquipped => 'Streak Freeze equipped! 🧊';

  @override
  String get maxFreezesHeld => 'Maximum freezes held! (2/2)';

  @override
  String notEnoughDiamonds(int count) {
    return 'Not enough diamonds ($count 💎 needed)';
  }

  @override
  String get freeAd => '1 Free Ad';

  @override
  String get repair => 'Repair';

  @override
  String get viewAll => 'View All';

  @override
  String get collections => 'Collections';

  @override
  String get favorites => 'Favorites';

  @override
  String get shelves => 'Shelves';

  @override
  String get fullGrid => 'Full Grid';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get notStarted => 'Not started';

  @override
  String get noArtworksFound => 'No artworks found';

  @override
  String get tryAnotherSearch => 'Try adjusting your search or filters';

  @override
  String get mysteryGift => 'Mystery Diamond Gift';

  @override
  String get claim => 'Claim';

  @override
  String get color => 'Color';

  @override
  String get unlock => 'Unlock';

  @override
  String get premiumArtwork => 'Premium Artwork';

  @override
  String get unlockThisOne => 'Unlock this one';

  @override
  String get tryWithAd => 'Try with Ad';

  @override
  String get notNow => 'Not now';

  @override
  String get noAdAvailable => 'No ad available right now — try again later.';

  @override
  String get sortDefault => 'Sort: Default';

  @override
  String get sortEasyFirst => 'Easy First';

  @override
  String get sortHardFirst => 'Hard First';

  @override
  String get sortFewColors => 'Few Colors';

  @override
  String get sortManyColors => 'Many Colors';

  @override
  String get exitDialogTitle => 'Leaving So Soon?';

  @override
  String get exitDialogMessage =>
      'Before you go, check out our other relaxing games or keep coloring!';

  @override
  String get exitDialogKeepPlaying => 'Keep Playing';

  @override
  String get exitDialogExit => 'Exit App';

  @override
  String get emptyGalleryTitle => 'Your Canvas is Empty';

  @override
  String get emptyGalleryMessage =>
      'Color artworks from the catalog to build your personal gallery collection!';

  @override
  String get startFirstArtwork => 'Start Your First Artwork 🎨';

  @override
  String get deleteArtwork => 'Delete Artwork';

  @override
  String get deleteArtworkConfirm => 'Are you sure you want to delete this?';

  @override
  String get delete => 'Delete';

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }
}
