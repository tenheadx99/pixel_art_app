import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/coloring_provider.dart';
import '../../config/app_constants.dart';
import '../../data/models/pixel_art.dart';
import '../../data/services/iap_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/settings_sheet.dart';
import '../../data/services/ad_service.dart';
import '../../ui/theme/app_style.dart';
import '../../ui/screens/coloring_screen.dart';
import '../../ui/screens/camera_screen.dart';
import '../../ui/screens/gallery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GalleryProvider, AppSettingsProvider>(
      builder: (context, gallery, settings, _) {
        // Filter + sort once per rebuild; the getter recomputes on each call
        // and the grid delegate would otherwise hit it per item.
        final catalog = gallery.filteredCatalog;
        return Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildHeader(context, gallery),
              if (gallery.dailyArt != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DailyPixelBanner(
                      gallery: gallery,
                      onPlay: () => _openColoring(context, gallery.dailyArt!),
                    ),
                  ),
                ),
              if (gallery.inProgressArts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ContinueRow(
                      gallery: gallery,
                      onOpen: (art) => _openColoring(context, art),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _CategoryFilter(gallery: gallery),
                ),
              ),
              gallery.isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : catalog.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: Text('No pixel art available')),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.78,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final art = catalog[index];
                          return _PixelArtCard(
                            art: art,
                            index: index,
                            isCompleted: gallery.isCompleted(art.id),
                            isFavorite: gallery.isFavorite(art.id),
                            isUnlocked: gallery.isUnlocked(
                              art,
                              settings.isProUser,
                            ),
                            progressPercent: gallery.progressPercent(art.id),
                            onTap: () => _openColoring(context, art),
                            onFavorite: () => gallery.toggleFavorite(art.id),
                          );
                        }, childCount: catalog.length),
                      ),
                    ),
            ],
          ),
          // Camera/Gallery stay reachable via the header icons; the bottom
          // slot is dedicated to the banner ad (free users only).
          bottomNavigationBar: settings.isProUser
              ? null
              : const SafeArea(child: AdBanner()),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, GalleryProvider gallery) {
    return SliverAppBar(
      expandedHeight: 240,
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
                child: _buildDecoCircle(120, Colors.white.withAlpha(15)),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: _buildDecoCircle(100, Colors.white.withAlpha(10)),
              ),
              Positioned(
                top: 40,
                right: 60,
                child: _buildDecoCircle(40, Colors.white.withAlpha(20)),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.palette,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pixely',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Relaxing Pixel Art',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.amber.shade300,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${gallery.catalog.length} artworks available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${gallery.completedIds.length} completed',
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                hintText: 'Search artworks...',
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

  void _openColoring(BuildContext context, PixelArt art) {
    final gallery = context.read<GalleryProvider>();
    final settings = context.read<AppSettingsProvider>();
    if (!gallery.isUnlocked(art, settings.isProUser)) {
      _showLockedDialog(context, art);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ColoringProvider>(),
          child: ColoringScreen(art: art),
        ),
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
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  void _openGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryScreen()),
    );
  }

  /// Lets the user watch a rewarded ad to try [art] for this session — both
  /// a revenue source and a taste of premium content that feeds Pro sales.
  void _tryPremiumWithAd(PixelArt art) {
    final adService = context.read<AdService>();
    final messenger = ScaffoldMessenger.of(context);
    adService.loadRewardedAd(
      onLoaded: () => adService.showRewardedAd(
        onRewarded: () {
          if (!mounted) return;
          context.read<GalleryProvider>().unlockForSession(art.id);
          _openColoring(context, art);
        },
      ),
      onFailed: () => messenger.showSnackBar(
        const SnackBar(
          content: Text('No ad available right now — try again later.'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  void _showLockedDialog(BuildContext context, PixelArt art) {
    final iap = context.read<IAPService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppStyle.primary),
            SizedBox(width: 8),
            Text('Pixely Pro'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProBenefit(
              icon: Icons.palette_outlined,
              text: 'Unlock every premium artwork',
            ),
            const _ProBenefit(icon: Icons.block, text: 'Remove all ads'),
            const _ProBenefit(
              icon: Icons.favorite_outline,
              text: 'Support future artwork packs',
            ),
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: iap.getPrice(AppConstants.proProductId),
              builder: (context, snapshot) {
                final price = snapshot.data;
                if (price == null) return const SizedBox.shrink();
                return Text(
                  'One-time purchase · $price',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppStyle.primary,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Try with Ad'),
            onPressed: () {
              Navigator.pop(ctx);
              _tryPremiumWithAd(art);
            },
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              iap.buyPro();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade ✨'),
          ),
        ],
      ),
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
              final pct = gallery.progressPercent(art.id);
              return GestureDetector(
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
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _PixelArtPreviewPainter(
                              art: art,
                              isCompleted: true,
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
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                minHeight: 5,
                                backgroundColor: AppStyle.primary.withAlpha(25),
                                color: AppStyle.primary,
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

  const _DailyPixelBanner({required this.gallery, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final art = gallery.dailyArt!;
    final done = gallery.dailyCompletedToday;
    final now = DateTime.now();
    final hoursToNext = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).difference(now).inHours;
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5E62).withAlpha(70),
              blurRadius: 12,
              offset: const Offset(0, 5),
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
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PixelArtPreviewPainter(art: art, isCompleted: true),
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
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.amber,
                        size: 16,
                      ),
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
                    ],
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.play_arrow_rounded,
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
          ],
        ),
      ),
    );
  }
}

class _ProBenefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProBenefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppStyle.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = gallery.selectedCategory == cat;
          return Padding(
            padding: EdgeInsets.only(right: 10, left: index == 0 ? 0 : 0),
            child: GestureDetector(
              onTap: () => gallery.setCategory(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
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
                                .withAlpha(80),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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

    return GestureDetector(
      // Locked items must still be tappable so _openColoring can present the
      // unlock dialog; gating onTap here is what made premium taps no-op.
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: AppStyle.primary.withAlpha(25),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _PixelArtPreviewPainter(
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
                  Padding(
                    padding: const EdgeInsets.all(10),
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
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                child: GestureDetector(
                  onTap: onFavorite,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? Colors.red.withAlpha(30)
                          : Colors.black.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                      size: 16,
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

class _PixelArtPreviewPainter extends CustomPainter {
  final PixelArt art;
  final bool isCompleted;

  _PixelArtPreviewPainter({required this.art, required this.isCompleted});

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / art.gridWidth;
    final ch = size.height / art.gridHeight;

    // One drawRawPoints call per color instead of a drawRect per cell —
    // a 128x128 preview is otherwise ~16k draw ops per card.
    final batches = <int, List<double>>{};
    for (var r = 0; r < art.gridHeight; r++) {
      for (var c = 0; c < art.gridWidth; c++) {
        final val = art.grid[r][c];
        if (val <= 0) continue;
        final color = art.colorForNumber(val) ?? Colors.transparent;
        final key = (isCompleted ? color : color.withAlpha(90)).toARGB32();
        batches.putIfAbsent(key, () => <double>[])
          ..add(c * cw + cw / 2)
          ..add(r * ch + ch / 2);
      }
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.square
      ..strokeWidth = max(cw, ch);
    for (final entry in batches.entries) {
      paint.color = Color(entry.key);
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.fromList(entry.value),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPreviewPainter oldDelegate) =>
      oldDelegate.art != art || oldDelegate.isCompleted != isCompleted;
}
