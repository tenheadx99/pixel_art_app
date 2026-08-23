import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/coloring_provider.dart';
import '../../config/app_config.dart';
import '../../data/models/pixel_art.dart';
import '../../data/models/split_art.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/remote_config_service.dart';
import '../../data/services/update_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/art_preview_painter.dart';
import '../widgets/coin_fly.dart';
import '../widgets/pressable.dart';
import '../widgets/rolling_count.dart';
import '../widgets/reward_popup.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/transitions.dart';
import '../../data/services/ad_service.dart';
import '../../ui/theme/app_style.dart';
import '../../ui/screens/coloring_screen.dart';
import '../../ui/screens/part_selection_screen.dart';
import '../../ui/screens/camera_screen.dart';
import '../../ui/screens/gallery_screen.dart';
import '../../ui/screens/paywall_screen.dart';
import '../../ui/screens/profile_screen.dart';
import '../../config/flavor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  // Coin bursts fly to the header's diamond chip, which pulses on arrival.
  final GlobalKey _diamondChipKey = GlobalKey();
  bool _diamondChipPulse = false;

  void _pulseDiamondChip() {
    if (!mounted) return;
    setState(() => _diamondChipPulse = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _diamondChipPulse = false);
    });
  }

  @override
  void initState() {
    super.initState();
    // Reminders deep-link to Daily Art. The flag may already be set from a
    // cold-start launch payload, or flip later when a reminder is tapped while
    // the app is running.
    final requested = NotificationService.instance.dailyArtRequested;
    requested.addListener(_handleDailyArtRequest);
    if (requested.value) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleDailyArtRequest(),
      );
    }
    // Surface the 50 diamond welcome bonus for new users on first time launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      final welcomeAward = settings.checkAndClaimWelcomeBonus();
      if (welcomeAward > 0) {
        showRewardPopup(
          context,
          icon: Icons.diamond_rounded,
          title: 'Welcome Bonus!',
          subtitle: 'Enjoy 50 free diamonds to start your pixel art journey!',
          diamonds: welcomeAward,
          buttonLabel: 'Claim Bonus',
          badgeColors: const [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
        );
      } else {
        final award = settings.maybeClaimDailyPlusStipend();
        if (award > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Daily Plus bonus · +$award 💎'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      // Check for Google Play Flexible in-app updates
      AppUpdateService().checkForUpdate(context: context);
    });
  }

  void _handleDailyArtRequest() {
    final notifier = NotificationService.instance.dailyArtRequested;
    if (!notifier.value || !mounted) return;
    notifier.value = false;
    final art = context.read<GalleryProvider>().dailyArt;
    if (art != null) _openColoring(context, art);
  }

  @override
  void dispose() {
    NotificationService.instance.dailyArtRequested.removeListener(
      _handleDailyArtRequest,
    );
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GalleryProvider, AppSettingsProvider>(
      builder: (context, gallery, settings, _) {
        gallery.checkAndGrantPlusMonthlyFreeze(settings.isPlusActive);
        // Filter + sort once per rebuild; the getter recomputes on each call
        // and the grid delegate would otherwise hit it per item.
        final catalog = gallery.filteredCatalog;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldExit = await _showExitConfirmationDialog(context);
            if (shouldExit && context.mounted) {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            body: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildHeader(context, gallery, settings),
                if (gallery.dailyArt != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _DailyPixelBanner(
                        gallery: gallery,
                        onPlay: () => _openColoring(context, gallery.dailyArt!),
                        showBonusClaim: _canEarnDiamondsViaAd &&
                            !settings.dailyStreakBonusClaimedToday,
                        bonusAmount: RemoteConfigService().dailyStreakAdBonus,
                        onClaimBonus: _claimDailyStreakBonus,
                      ),
                    ),
                  ),
                if (gallery.inProgressArts.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ContinueRow(
                        gallery: gallery,
                        onOpen: (art) => _openColoring(context, art),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: _CategoryFilter(gallery: gallery),
                  ),
                ),
                if (!gallery.isLoading && catalog.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ResultsCount(gallery: gallery, count: catalog.length),
                  ),
                if (gallery.isLoading)
                  const _SkeletonGrid()
                else if (catalog.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(gallery: gallery),
                  )
                else
                  ..._buildCatalogSlivers(gallery, settings, catalog),
              ],
            ),
            // Camera/Gallery stay reachable via the header icons; the bottom
            // slot is dedicated to the banner ad (free users only).
            bottomNavigationBar: settings.isProUser
                ? null
                : const SafeArea(child: AdBanner()),
          ),
        );
      },
    );
  }

  /// The catalog grid, split into segments with a full-row native ad between
  /// them: after the first 6 artworks (3 grid rows — never above the fold,
  /// never adjacent to the continue row) and then every 12. Free users only;
  /// NativeAdCard itself stays at zero height when native ads are
  /// unconfigured or killed via Remote Config, and the 18dp inter-segment
  /// padding then reads as the normal row gap.
  List<Widget> _buildCatalogSlivers(
    GalleryProvider gallery,
    AppSettingsProvider settings,
    List<PixelArt> catalog,
  ) {
    SliverPadding gridSegment(int start, int end, {required bool last}) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(
          16,
          start == 0 ? 16 : 0,
          16,
          last ? 100 : 18,
        ),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 0.78,
          ),
          delegate: SliverChildBuilderDelegate((context, i) {
            final index = start + i;
            final art = catalog[index];
            return _PixelArtCard(
              art: art,
              index: index,
              isCompleted: gallery.isCompleted(art.id),
              isFavorite: gallery.isFavorite(art.id),
              isUnlocked: gallery.isUnlocked(art, settings.isProUser),
              progressPercent: gallery.artProgressPercent(art),
              onTap: () => _openColoring(context, art),
              onFavorite: () => gallery.toggleFavorite(art.id),
            );
          }, childCount: end - start),
        ),
      );
    }

    if (settings.isProUser) {
      return [gridSegment(0, catalog.length, last: true)];
    }
    final slivers = <Widget>[];
    var start = 0;
    var segment = 6;
    while (start < catalog.length) {
      final end = start + segment < catalog.length
          ? start + segment
          : catalog.length;
      slivers.add(gridSegment(start, end, last: end == catalog.length));
      if (end < catalog.length) {
        slivers.add(const SliverToBoxAdapter(child: NativeAdCard()));
      }
      start = end;
      segment = 12;
    }
    return slivers;
  }

  Widget _buildHeader(
    BuildContext context,
    GalleryProvider gallery,
    AppSettingsProvider settings,
  ) {
    return SliverAppBar(
      expandedHeight: 276,
      pinned: false,
      floating: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppStyle.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: _buildDecoCircle(120, Colors.white.withAlpha(10)),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: _buildDecoCircle(100, Colors.white.withAlpha(8)),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              FlavorConfig.current.appIconPath,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                FlavorConfig.current.appName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                FlavorConfig.current.splashTagline,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  letterSpacing: 1.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _HeaderIconButton(
                          icon: Icons.photo_camera,
                          onTap: () => _openCamera(context),
                        ),
                        const SizedBox(width: 8),
                        _HeaderIconButton(
                          icon: Icons.photo_library,
                          onTap: () => _openGallery(context),
                        ),
                        const SizedBox(width: 8),
                        _HeaderIconButton(
                          icon: Icons.settings_outlined,
                          onTap: () => showSettingsSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPlayerStrip(context, gallery, settings),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TextField(
                              onChanged: (val) => gallery.setSearchQuery(val),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)?.searchHint ?? 'Search artworks...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withAlpha(160),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(canvasColor: AppStyle.primary),
                              child: DropdownButton<String>(
                                value: gallery.sortBy,
                                icon: const Icon(
                                  Icons.sort,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (val) {
                                  if (val != null) gallery.setSortBy(val);
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Default',
                                    child: Text('Sort: Default'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Difficulty (Easy)',
                                    child: Text('Easy First'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Difficulty (Hard)',
                                    child: Text('Hard First'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Colors (Few)',
                                    child: Text('Few Colors'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Colors (Many)',
                                    child: Text('Many Colors'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecoCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  /// Gamified header strip: level badge + XP bar + diamond balance. Tapping it
  /// opens the profile/stats screen.
  Widget _buildPlayerStrip(
    BuildContext context,
    GalleryProvider gallery,
    AppSettingsProvider settings,
  ) {
    return GestureDetector(
      onTap: () => _openProfile(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Level badge.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFD24C), Color(0xFFFF9D2E)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9D2E).withAlpha(120),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                '${settings.playerLevel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Streak Flame Badge
            GestureDetector(
              onTap: () => _showStreakMilestoneDialog(context, gallery, settings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(100), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${gallery.dailyStreak}d',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Level ${settings.playerLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${gallery.completedIds.length} done',
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: settings.xpProgressInLevel),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: Colors.white.withAlpha(45),
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Diamond balance. When free-diamond claims remain, a "+" appears
            // and tapping the chip offers a rewarded ad instead of opening
            // the profile.
            Builder(builder: (context) {
              final canEarn = _canEarnDiamondsViaAd &&
                  settings.freeDiamondClaimsRemaining > 0;
              return GestureDetector(
                onTap: canEarn
                    ? () => _watchAdForDiamonds('home_free_diamonds')
                    : null,
                child: AnimatedScale(
                  scale: _diamondChipPulse ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Container(
                  key: _diamondChipKey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RollingCount(
                        settings.diamondsAvailable,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.diamond_rounded,
                        color: Color(0xFFFFE08A),
                        size: 15,
                      ),
                      if (canEarn) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.add_circle_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStreakMilestoneDialog(
    BuildContext context,
    GalleryProvider gallery,
    AppSettingsProvider settings,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final streak = gallery.dailyStreak;
        final milestones = [
          {'day': 3, 'reward': '+2 Wands 🪄'},
          {'day': 7, 'reward': '+100 Diamonds 💎'},
          {'day': 14, 'reward': '+5 Bombs 💣'},
          {'day': 30, 'reward': 'Crown & +250 💎'},
        ];

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text('$streak Day Streak!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Color daily to keep your flame burning and unlock milestone gifts!',
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 16),
              ...milestones.map((m) {
                final day = m['day'] as int;
                final reward = m['reward'] as String;
                final isReached = streak >= day;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isReached ? Colors.orange.withAlpha(25) : Colors.grey.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isReached ? Colors.orange.withAlpha(120) : Colors.grey.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isReached ? Icons.check_circle_rounded : Icons.lock_clock_outlined,
                          color: isReached ? Colors.orange : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Day $day',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          reward,
                          style: TextStyle(
                            color: isReached ? Colors.orange : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Awesome!'),
            ),
          ],
        );
      },
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
        context, fadeThroughRoute(const ProfileScreen(), name: 'profile'));
  }

  void _openColoring(BuildContext context, PixelArt art) {
    final gallery = context.read<GalleryProvider>();
    final settings = context.read<AppSettingsProvider>();
    if (!gallery.isUnlocked(art, settings.isProUser)) {
      _showLockedDialog(context, art);
      return;
    }
    // Split artworks open on the part picker; each tile is then colored as
    // its own small canvas.
    if (art.isSplit && SplitArt.validSplit(art)) {
      Navigator.push(
        context,
        fadeThroughRoute(
          PartSelectionScreen(parent: art),
          name: 'part_selection',
        ),
      ).then((_) {
        if (context.mounted) context.read<GalleryProvider>().refresh();
      });
      return;
    }
    Navigator.push(
      context,
      fadeThroughRoute(
        ChangeNotifierProvider.value(
          value: context.read<ColoringProvider>(),
          child: ColoringScreen(art: art),
        ),
        name: 'coloring',
      ),
    ).then((_) {
      // Progress badges and the continue row read prefs written while
      // coloring; refresh them on return.
      if (context.mounted) context.read<GalleryProvider>().refresh();
    });
  }

  void _openCamera(BuildContext context) {
    Navigator.push(
      context,
      fadeThroughRoute(const CameraScreen(), name: 'camera'),
    );
  }

  void _openGallery(BuildContext context) {
    Navigator.push(
      context,
      fadeThroughRoute(const GalleryScreen(), name: 'gallery'),
    );
  }

  /// Lets the user watch a rewarded ad to try [art] for this session — both
  /// a revenue source and a taste of premium content that feeds Pro sales.
  void _tryPremiumWithAd(PixelArt art) {
    final adService = context.read<AdService>();
    final messenger = ScaffoldMessenger.of(context);
    adService.showRewardedAd(
      placement: 'premium_try',
      onRewarded: () {
        if (!mounted) return;
        context.read<GalleryProvider>().unlockForSession(art.id);
        _openColoring(context, art);
      },
      onUnavailable: () => messenger.showSnackBar(
        const SnackBar(
          content: Text('No ad available right now — try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  /// Whether the diamond-earning rewarded affordances (home pill, streak
  /// bonus) should render: ads on for this flavor + Remote Config kill switch.
  bool get _canEarnDiamondsViaAd =>
      !AppConfig.disableAds &&
      AppConfig.showAds &&
      RemoteConfigService().freeDiamondsEnabled;

  /// Watch a rewarded ad for a capped daily diamond payout. Shares its daily
  /// claim pool with the coloring screen's shop tile.
  void _watchAdForDiamonds(String placement) {
    final settings = context.read<AppSettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    void grant() {
      final amount = settings.claimFreeDiamonds();
      if (amount <= 0 || !mounted) return;
      showCoinBurst(
        context,
        target: centerOfKey(_diamondChipKey),
        onArrive: _pulseDiamondChip,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('+$amount diamonds!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    context.read<AdService>().showRewardedAd(
      placement: placement,
      onRewarded: grant,
      onUnavailable: () => messenger.showSnackBar(
        const SnackBar(
          content: Text('No ad available right now — try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  /// Once-a-day rewarded bonus for keeping the daily streak going, claimed
  /// from the daily banner after today's artwork is finished.
  void _claimDailyStreakBonus() {
    final settings = context.read<AppSettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    void grant() {
      final amount = settings.claimDailyStreakBonus();
      if (amount <= 0 || !mounted) return;
      showRewardPopup(
        context,
        icon: Icons.local_fire_department,
        title: 'Streak Bonus!',
        subtitle: '${context.read<GalleryProvider>().dailyStreak} day streak',
        diamonds: amount,
      );
    }

    context.read<AdService>().showRewardedAd(
      placement: 'daily_streak_bonus',
      onRewarded: grant,
      onUnavailable: () => messenger.showSnackBar(
        const SnackBar(
          content: Text('No ad available right now — try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
        final subColor = isDark ? Colors.white70 : Colors.black54;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF2A2440), const Color(0xFF1B1830)]
                    : [Colors.white, const Color(0xFFF3F0FF)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppStyle.primary.withAlpha(70),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(70),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B6B), Color(0xFFEE5253)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEE5253).withAlpha(130),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Exit ${FlavorConfig.current.appName}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to exit the app?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: subColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF6B6B), Color(0xFFEE5253)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEE5253).withAlpha(90),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  void _showLockedDialog(BuildContext context, PixelArt art) {
    final unlockCost = art.unlockDiamondCost;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
        final subColor = isDark ? Colors.white70 : Colors.black54;
        // Consumer so the diamond balance / affordability stay live.
        return Consumer<AppSettingsProvider>(
          builder: (_, settings, _) {
            final diamonds = settings.diamondsAvailable;
            final canAfford = diamonds >= unlockCost;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF2A2440), const Color(0xFF1B1830)]
                        : [Colors.white, const Color(0xFFF3F0FF)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppStyle.primary.withAlpha(70),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(70),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFB14CFF), Color(0xFF7A2BE2)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppStyle.primary.withAlpha(130),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Premium Artwork',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      art.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: subColor),
                    ),
                    const SizedBox(height: 18),
                    _ProBenefit(
                      icon: Icons.palette_outlined,
                      text: 'Unlock every premium artwork',
                      color: titleColor,
                    ),
                    _ProBenefit(
                      icon: Icons.block,
                      text: 'Remove all ads',
                      color: titleColor,
                    ),
                    _ProBenefit(
                      icon: Icons.favorite_outline,
                      text: 'Support future artwork packs',
                      color: titleColor,
                    ),
                    const SizedBox(height: 18),
                    // Spend diamonds to unlock just this artwork, forever.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canAfford
                            ? () {
                                if (settings.useDiamonds(unlockCost)) {
                                  HapticFeedback.mediumImpact();
                                  context
                                      .read<GalleryProvider>()
                                      .unlockWithDiamonds(art.id);
                                  Navigator.pop(ctx);
                                  _openColoring(context, art);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.diamond_rounded, size: 18),
                        label: Text('Unlock this one · $unlockCost'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9D2E),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.withAlpha(80),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        canAfford
                            ? 'You have $diamonds 💎'
                            : 'You have $diamonds 💎 · need ${unlockCost - diamonds} more',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (RemoteConfigService().premiumArtworksEnabled) ...[
                      // Plus paywall — subscriptions + lifetime Pro in one place.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              fadeThroughRoute(
                                const PaywallScreen(source: 'home'),
                                name: 'paywall',
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyle.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Unlock everything with ${FlavorConfig.current.appName} Plus ✨',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('Try with Ad'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _tryPremiumWithAd(art);
                          },
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Not now',
                            style: TextStyle(color: subColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ContinueRow extends StatelessWidget {
  final GalleryProvider gallery;
  final void Function(PixelArt art) onOpen;

  const _ContinueRow({required this.gallery, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final arts = gallery.inProgressArts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Jump back in',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: arts.length,
            itemBuilder: (context, index) {
              final art = arts[index];
              final pct = gallery.artProgressPercent(art);
              return PressableScale(
                onTap: () => onOpen(art),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppStyle.primary.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        // Center + AspectRatio so portrait/landscape art
                        // letterboxes instead of stretching to the square box.
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: art.gridWidth / art.gridHeight,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: ArtPreviewPainter(
                                  art: art,
                                  isCompleted: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              art.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: pct / 100),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) =>
                                    LinearProgressIndicator(
                                  value: v,
                                  minHeight: 5,
                                  backgroundColor:
                                      AppStyle.primary.withAlpha(25),
                                  color: AppStyle.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$pct% done',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DailyPixelBanner extends StatelessWidget {
  final GalleryProvider gallery;
  final VoidCallback onPlay;

  /// When true and today's daily is done, the trailing chip becomes a
  /// watch-ad streak-bonus claim instead of the static "Done" state.
  final bool showBonusClaim;
  final int bonusAmount;
  final VoidCallback? onClaimBonus;

  const _DailyPixelBanner({
    required this.gallery,
    required this.onPlay,
    this.showBonusClaim = false,
    this.bonusAmount = 0,
    this.onClaimBonus,
  });

  @override
  Widget build(BuildContext context) {
    if (gallery.canRepairStreak) {
      return PressableScale(
        onTap: () => _showStreakRepairSheet(
          context,
          gallery,
          context.read<AppSettingsProvider>(),
        ),
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFC2185B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withAlpha(40),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.heart_broken_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STREAK LOST • REPAIR WITHIN 48H',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Restore ${gallery.streakBrokenValue}-Day Streak!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to restore with 300 💎 or 1 Ad',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.build_rounded,
                      color: Color(0xFFE53935),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Repair',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final art = gallery.dailyArt!;
    final done = gallery.dailyCompletedToday;
    final claimable = done && showBonusClaim && onClaimBonus != null;
    final now = DateTime.now();
    final hoursToNext = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).difference(now).inHours;
    final settings = context.read<AppSettingsProvider>();

    return PressableScale(
      onTap: onPlay,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD98E73), Color(0xFFC97E68)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC97E68).withAlpha(35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AspectRatio(
                  aspectRatio: art.gridWidth / art.gridHeight,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ArtPreviewPainter(art: art, isCompleted: true),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DAILY PIXEL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    art.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Breathes while today's daily is uncolored — a quiet
                      // "the streak needs you" nudge; still when done.
                      _BreathingFlame(active: !done),
                      const SizedBox(width: 4),
                      Text(
                        done
                            ? '${gallery.dailyStreak} day streak · new in ${hoursToNext}h'
                            : '${gallery.dailyStreak} day streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Freeze count indicator / buy affordance
                      GestureDetector(
                        onTap: () => _showBuyFreezeDialog(
                          context,
                          gallery,
                          settings,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🧊', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 2),
                              Text(
                                '${gallery.streakFreezes}/2',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PressableScale(
              // Intercepts the banner's onPlay tap when the bonus is claimable.
              onTap: claimable ? onClaimBonus : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                // Play → Done → claim transitions pop instead of snapping.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Row(
                    key: ValueKey(
                      claimable ? 'claim' : (done ? 'done' : 'play'),
                    ),
                    mainAxisSize: MainAxisSize.min,
                    children: claimable
                        ? [
                            const Icon(
                              Icons.card_giftcard_rounded,
                              color: Color(0xFFFF5E62),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+$bonusAmount',
                              style: const TextStyle(
                                color: Color(0xFFFF5E62),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.diamond_rounded,
                              color: Color(0xFFFF5E62),
                              size: 14,
                            ),
                          ]
                        : [
                            Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFFFF5E62),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              done ? 'Done' : 'Play',
                              style: const TextStyle(
                                color: Color(0xFFFF5E62),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showStreakRepairSheet(
  BuildContext context,
  GalleryProvider gallery,
  AppSettingsProvider settings,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1830) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9D2E), Color(0xFFFF5E62)],
                ),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Restore Your ${gallery.streakBrokenValue}-Day Streak!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2A2440),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Don\'t lose your progress! Restore within 48 hours to keep your streak alive.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      final adService = context.read<AdService>();
                      gallery.repairStreakWithAd(adService, () {
                        if (context.mounted) {
                          showRewardPopup(
                            context,
                            icon: Icons.local_fire_department,
                            title: 'Streak Restored! 🔥',
                            subtitle: '${gallery.dailyStreak} Day Streak Intact',
                            badgeColors: const [
                              Color(0xFFFF9D2E),
                              Color(0xFFFF5E62),
                            ],
                          );
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5E62),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ondemand_video_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '1 Free Ad',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (settings.diamondsAvailable < 300) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Not enough diamonds (300 💎 needed)',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final success =
                          gallery.repairStreakWithDiamonds(settings);
                      if (success && context.mounted) {
                        showRewardPopup(
                          context,
                          icon: Icons.local_fire_department,
                          title: 'Streak Restored! 🔥',
                          subtitle: '${gallery.dailyStreak} Day Streak Intact',
                          badgeColors: const [
                            Color(0xFFFF9D2E),
                            Color(0xFFFF5E62),
                          ],
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9D2E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '300',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.diamond_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _showBuyFreezeDialog(
  BuildContext context,
  GalleryProvider gallery,
  AppSettingsProvider settings,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
  final subColor = isDark ? Colors.white70 : Colors.black54;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1830) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppStyle.primary.withAlpha(70), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4FC3F7).withAlpha(40),
              ),
              child: const Icon(
                Icons.ac_unit_rounded,
                color: Color(0xFF0288D1),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Streak Freeze',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Equip a freeze to automatically save your streak if you miss a day! (Max 2 held · Currently: ${gallery.streakFreezes}/2)',
              style: TextStyle(fontSize: 13, color: subColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (gallery.streakFreezes >= 2)
              Text(
                'Maximum freezes held! (2/2)',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (settings.diamondsAvailable < 150) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Not enough diamonds (150 💎 needed)',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        final success = gallery.buyStreakFreeze(settings);
                        Navigator.pop(ctx);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Streak Freeze equipped! 🧊'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0288D1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '150',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.diamond_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

/// The streak flame, breathing on a slow cosine while [active] (same rhythm
/// as the canvas's next-cell pulse) and static otherwise.
class _BreathingFlame extends StatefulWidget {
  final bool active;

  const _BreathingFlame({required this.active});

  @override
  State<_BreathingFlame> createState() => _BreathingFlameState();
}

class _BreathingFlameState extends State<_BreathingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BreathingFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: const Icon(
        Icons.local_fire_department,
        color: Colors.amber,
        size: 16,
      ),
    );
  }
}

class _ProBenefit extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _ProBenefit({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppStyle.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: color == null ? null : TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final GalleryProvider gallery;

  const _CategoryFilter({required this.gallery});

  @override
  Widget build(BuildContext context) {
    final categories = gallery.categories;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Index 0 is the Favorites toggle; the rest are categories.
        itemCount: categories.length + 1,
        itemBuilder: (context, rawIndex) {
          if (rawIndex == 0) {
            final on = gallery.favoritesOnly;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: PressableScale(
                onTap: () => gallery.toggleFavoritesOnly(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: on ? Colors.red : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: on
                          ? Colors.transparent
                          : Theme.of(context).dividerColor.withAlpha(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(on ? Icons.favorite : Icons.favorite_border,
                          size: 16, color: on ? Colors.white : null),
                      const SizedBox(width: 6),
                      Text('Favorites',
                          style: TextStyle(
                            color: on ? Colors.white : null,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }
          final index = rawIndex - 1;
          final cat = categories[index];
          final isSelected = gallery.selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: PressableScale(
              onTap: () => gallery.setCategory(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: AppColors.gradientForIndex(index),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Theme.of(context).dividerColor.withAlpha(30),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors
                                .categoryColors[index %
                                    AppColors.categoryColors.length]
                                .withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Stateless on purpose: a per-card entrance AnimationController repainted
// every card for 400ms each time it scrolled into view, which made the
// listing stutter.
class _PixelArtCard extends StatelessWidget {
  final PixelArt art;
  final int index;
  final bool isCompleted;
  final bool isFavorite;
  final bool isUnlocked;
  final int progressPercent;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _PixelArtCard({
    required this.art,
    required this.index,
    required this.isCompleted,
    required this.isFavorite,
    required this.isUnlocked,
    this.progressPercent = 0,
    required this.onTap,
    required this.onFavorite,
  });

  bool get _inProgress =>
      !isCompleted && progressPercent > 0 && progressPercent < 100;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.gradientForIndex(index);

    return PressableScale(
      // Locked items must still be tappable so _openColoring can present the
      // unlock dialog; gating onTap here is what made premium taps no-op.
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors[0].withAlpha(60),
                            colors[1].withAlpha(40),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: AspectRatio(
                            aspectRatio: art.gridWidth / art.gridHeight,
                            // Own layer: the card's entrance animation
                            // must not re-rasterize the preview.
                            child: Hero(
                              tag: 'art_canvas_${art.id}',
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: ArtPreviewPainter(
                                    art: art,
                                    isCompleted: isCompleted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          art.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            ...List.generate(
                              art.sortedNumbers.length > 4
                                  ? 4
                                  : art.sortedNumbers.length,
                              (i) {
                                final num = art.sortedNumbers[i];
                                final color =
                                    art.colorForNumber(num) ??
                                    AppStyle.numberToColor(num);
                                return Align(
                                  widthFactor: 0.7,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (art.colorCount > 4)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  '+${art.colorCount - 4}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Icon(
                              Icons.grid_on,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${art.gridWidth}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isUnlocked)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, color: Colors.white, size: 28),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppStyle.primary, AppStyle.secondary],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open_rounded,
                                  color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Unlock',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isUnlocked)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(Icons.workspace_premium,
                      color: Color(0xFFFFD54F), size: 20),
                ),
              if (_inProgress)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppStyle.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (isCompleted)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B894).withAlpha(100),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: PressableScale(
                  onTap: onFavorite,
                  scale: 0.85,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? Colors.red.withAlpha(30)
                          : Colors.black.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(isFavorite),
                        color: isFavorite ? Colors.red : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live result count + a one-tap "Clear" affordance when filters are active.
class _ResultsCount extends StatelessWidget {
  final GalleryProvider gallery;
  final int count;

  const _ResultsCount({required this.gallery, required this.count});

  @override
  Widget build(BuildContext context) {
    final q = gallery.searchQuery;
    final label = '$count artwork${count == 1 ? '' : 's'}'
        '${q.isNotEmpty ? ' for "$q"' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 20, 0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
          const Spacer(),
          if (gallery.hasActiveFilter)
            GestureDetector(
              onTap: gallery.clearFilters,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 14, color: AppStyle.primary),
                  const SizedBox(width: 3),
                  Text('Clear filters',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.primary,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder shimmer cards shown while the catalog loads, instead of a bare
/// spinner — keeps the gallery's shape so the load feels faster.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _ShimmerCard(delayFraction: (index % 4) / 4),
          childCount: 6,
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  final double delayFraction;
  const _ShimmerCard({required this.delayFraction});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade300
        : Colors.white.withAlpha(20);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // A highlight band sweeping diagonally across the card — an actual
        // shimmer rather than an opacity blink.
        final t = ((_c.value + widget.delayFraction) % 1.0);
        return Container(
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, Color.lerp(base, Colors.white, 0.35)!, base],
              stops: [
                (t * 1.6 - 0.5).clamp(0.0, 1.0),
                (t * 1.6 - 0.3).clamp(0.0, 1.0),
                (t * 1.6 - 0.1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Friendly empty state that distinguishes "no matches for current filters"
/// from "the catalog itself is empty".
class _EmptyState extends StatelessWidget {
  final GalleryProvider gallery;
  const _EmptyState({required this.gallery});

  @override
  Widget build(BuildContext context) {
    final filtered = gallery.hasActiveFilter;
    final q = gallery.searchQuery;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off_rounded : Icons.palette_outlined,
              size: 56,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No matches found' : 'No artworks yet',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? (q.isNotEmpty
                      ? 'Nothing matches "$q" with the current filters.'
                      : 'No artworks match the current filters.')
                  : 'Pull to refresh, or check back soon for new pieces.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Theme.of(context).hintColor),
            ),
            if (filtered) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: gallery.clearFilters,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Clear filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

