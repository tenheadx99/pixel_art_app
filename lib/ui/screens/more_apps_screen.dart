import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/flavor.dart';
import '../../data/models/promoted_app.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/promoted_apps_service.dart';
import '../widgets/pressable.dart';

class MoreAppsScreen extends StatefulWidget {
  const MoreAppsScreen({super.key});

  @override
  State<MoreAppsScreen> createState() => _MoreAppsScreenState();
}

class _MoreAppsScreenState extends State<MoreAppsScreen> {
  late final PromotedAppsService _service;
  List<PromotedApp>? _apps;
  bool _isLoading = true;
  StreamSubscription<List<PromotedApp>>? _subscription;

  @override
  void initState() {
    super.initState();
    final storage = context.read<LocalStorageService>();
    _service = PromotedAppsService(storage);
    _loadApps();
    try {
      _subscription = _service.streamPromotedApps().listen(
        (apps) {
          if (mounted && apps.isNotEmpty) {
            setState(() {
              _apps = apps;
              _isLoading = false;
            });
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _service.getPromotedApps();
    if (mounted) {
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flavor = FlavorConfig.current;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF7F8FD),
      appBar: AppBar(
        title: const Text(
          'More Games & Apps',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadApps,
              color: flavor.primary,
              child: _apps == null || _apps!.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildAppsList(_apps!, isDark, flavor),
            ),
    );
  }

  Widget _buildAppsList(List<PromotedApp> apps, bool isDark, FlavorConfig flavor) {
    // Sort apps by sortOrder
    final sortedApps = List<PromotedApp>.from(apps)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final top3 = sortedApps.take(3).toList();
    final remaining = sortedApps.skip(3).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _buildHeaderBanner(isDark, flavor),
        const SizedBox(height: 22),

        if (top3.isNotEmpty) ...[
          _buildSectionHeader(
            '🔥 TOP FEATURED GAMES',
            'Our most popular and highest rated coloring experiences',
            isDark,
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < top3.length; i++)
            _buildHeroCard(top3[i], i, isDark, flavor),
        ],

        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(
            '🎮 ALL GAMES & APPS',
            'Explore our full collection of creative pixel worlds',
            isDark,
          ),
          const SizedBox(height: 12),
          for (final app in remaining)
            _buildAppCard(app, isDark, flavor),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(PromotedApp app, int index, bool isDark, FlavorConfig flavor) {
    // Rank-based styling for Top 3
    final (rankTitle, rankGradient, rankBorderColor) = switch (index) {
      0 => (
        '👑 #1 TOP FEATURED',
        const [Color(0xFFFFD700), Color(0xFFFF9D2E)],
        const Color(0xFFFFD700),
      ),
      1 => (
        '🔥 #2 POPULAR HIT',
        const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        const Color(0xFFFF416C),
      ),
      _ => (
        '✨ #3 MUST PLAY',
        const [Color(0xFF8A2387), Color(0xFFE94057)],
        const Color(0xFFE94057),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PressableScale(
        onTap: () {
          HapticFeedback.lightImpact();
          PromotedAppsService.openAppStore(app);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B2D) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? rankBorderColor.withAlpha(55)
                  : rankBorderColor.withAlpha(45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: rankBorderColor.withAlpha(isDark ? 30 : 20),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 60 : 10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Rank Ribbon & Optional Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: rankGradient),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: rankGradient.first.withAlpha(100),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      rankTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (app.badge != null && app.badge!.trim().isNotEmpty)
                    _buildBadge(app.badge!),
                ],
              ),
              const SizedBox(height: 14),

              // Main App Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Bigger 76x76 Icon with Rounded Squircle
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: _buildAppIcon(app, isDark, size: 76),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // App Title & Rating Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withAlpha(isDark ? 40 : 30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: Color(0xFFFFB300),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    app.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? const Color(0xFFFFD54F)
                                          : const Color(0xFFD77C00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withAlpha(15)
                                    : Colors.black.withAlpha(8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    size: 13,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    app.downloadCount,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Descriptive Tagline (up to 2 lines for full hero impact)
              Text(
                app.tagline,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),

              // Full-Width Google Play Install Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2B2B45), const Color(0xFF222238)]
                        : [const Color(0xFFF3F5FC), const Color(0xFFE8EBF5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GooglePlayIcon(size: 20),
                    const SizedBox(width: 9),
                    Text(
                      'GET ON GOOGLE PLAY',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: isDark ? Colors.white70 : Colors.black54,
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

  Widget _buildHeaderBanner(bool isDark, FlavorConfig flavor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: flavor.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: flavor.brandGradient.first.withAlpha(isDark ? 90 : 60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore Our World',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'More relaxing coloring & puzzle experiences',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(PromotedApp app, bool isDark, FlavorConfig flavor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableScale(
        onTap: () {
          HapticFeedback.lightImpact();
          PromotedAppsService.openAppStore(app);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B2A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App Icon with Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _buildAppIcon(app, isDark),
                    ),
                  ),
                  if (app.badge != null && app.badge!.trim().isNotEmpty)
                    Positioned(
                      top: -6,
                      left: -6,
                      child: _buildBadge(app.badge!),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // App Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      app.tagline,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFFB300),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          app.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            app.downloadCount,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Google Play Store Action Button (replacing the GET button)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF232338) : const Color(0xFFF1F3F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(22) : Colors.black.withAlpha(15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 60 : 15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const GooglePlayIcon(size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(PromotedApp app, bool isDark, {double size = 64}) {
    final localAsset = _resolveLocalAsset(app);
    final trimmedUrl = app.iconUrl.trim();
    final isNetwork = trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://');

    if (isNetwork) {
      return Image.network(
        trimmedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (localAsset != null) {
            return Image.asset(
              localAsset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallbackIcon(app, isDark, size: size),
            );
          }
          return _buildFallbackIcon(app, isDark, size: size);
        },
      );
    }

    if (localAsset != null) {
      return Image.asset(
        localAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(app, isDark, size: size),
      );
    }

    return _buildFallbackIcon(app, isDark, size: size);
  }

  String? _resolveLocalAsset(PromotedApp app) {
    var raw = app.iconUrl.trim();
    if (raw.isNotEmpty) {
      // Normalize any flavors/ path coming from Firestore or admin seeds
      raw = raw.replaceAll('icons/flavors/', 'icons/').replaceAll('flavors/', '');

      // Explicitly check for original / pixely app icon
      if (raw.contains('original') || raw.contains('pixely') || raw.contains('app_icon')) {
        return 'assets/icons/original.png';
      }

      if (raw.startsWith('assets/')) return raw;
      if (raw.startsWith('icons/')) return 'assets/$raw';
      if (raw.endsWith('.png')) return 'assets/icons/$raw';
    }

    // Map by id, packageName, or title to built-in flavor assets
    final key = '${app.id} ${app.packageName} ${app.title}'.toLowerCase();
    if (key.contains('pixely') || key.contains('original')) {
      return 'assets/icons/original.png';
    }
    if (key.contains('divine') || key.contains('devotional') || key.contains('bhakti')) {
      return 'assets/icons/devotional.png';
    }
    if (key.contains('anime')) {
      return 'assets/icons/anime.png';
    }
    if (key.contains('calm') || key.contains('pixelcalm')) {
      return 'assets/icons/pixelcalm.png';
    }
    if (key.contains('bible')) {
      return 'assets/icons/bible.png';
    }
    if (key.contains('gem') || key.contains('diamond')) {
      return 'assets/icons/diamond.png';
    }
    if (key.contains('stitch') || key.contains('craftcolor')) {
      return 'assets/icons/cross_stitch.png';
    }
    if (key.contains('bead')) {
      return 'assets/icons/bead.png';
    }
    if (key.contains('brick')) {
      return 'assets/icons/brick.png';
    }
    if (key.contains('knit')) {
      return 'assets/icons/knit.png';
    }
    if (key.contains('mosaic')) {
      return 'assets/icons/mosaic.png';
    }
    if (key.contains('glow')) {
      return 'assets/icons/glow.png';
    }
    if (key.contains('sticker')) {
      return 'assets/icons/sticker.png';
    }
    if (key.contains('quilt')) {
      return 'assets/icons/quilt.png';
    }
    if (key.contains('voxel')) {
      return 'assets/icons/voxel.png';
    }

    return null;
  }

  Widget _buildFallbackIcon(PromotedApp app, bool isDark, {double size = 64}) {
    final initial = app.title.trim().isNotEmpty
        ? app.title.trim().characters.first.toUpperCase()
        : '★';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A2BE2), Color(0xFFFF007F)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildBadge(String badge) {
    final badgeUpper = badge.toUpperCase();
    final gradient = switch (badgeUpper) {
      'NEW' => const [Color(0xFF00C6FF), Color(0xFF0072FF)],
      'HOT' => const [Color(0xFFFF0844), Color(0xFFFFB199)],
      'POPULAR' => const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      _ => const [Color(0xFF8A2387), Color(0xFFE94057)],
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withAlpha(120),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        badgeUpper,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_rounded,
                size: 48,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
              const SizedBox(height: 12),
              Text(
                'No promoted games found',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black45,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pull down to refresh',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Official 4-color Google Play Store logo triangle.
class GooglePlayIcon extends StatelessWidget {
  final double size;

  const GooglePlayIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GooglePlayPainter(),
      ),
    );
  }
}

class _GooglePlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Exact Google Play Brand Triangle coordinates
    final pLeftTop = Offset(w * 0.08, h * 0.07);
    final pLeftBottom = Offset(w * 0.08, h * 0.93);
    final pApex = Offset(w * 0.92, h * 0.50);
    final pCenter = Offset(w * 0.50, h * 0.50);
    final pRightTop = Offset(w * 0.70, h * 0.3874);
    final pRightBottom = Offset(w * 0.70, h * 0.6126);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Blue Trapezoid (Left)
    final bluePath = Path()
      ..moveTo(pLeftTop.dx, pLeftTop.dy)
      ..lineTo(pLeftBottom.dx, pLeftBottom.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..close();
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF00D3FF), Color(0xFF007EE5)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bluePath, paint);

    // 2. Green Top Triangle
    final greenPath = Path()
      ..moveTo(pLeftTop.dx, pLeftTop.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..close();
    paint.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF00E676), Color(0xFF00C853)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(greenPath, paint);

    // 3. Red Bottom Triangle
    final redPath = Path()
      ..moveTo(pLeftBottom.dx, pLeftBottom.dy)
      ..lineTo(pRightBottom.dx, pRightBottom.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..close();
    paint.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFFF334B), Color(0xFFD50000)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(redPath, paint);

    // 4. Yellow Right Triangle
    final yellowPath = Path()
      ..moveTo(pCenter.dx, pCenter.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pApex.dx, pApex.dy)
      ..lineTo(pRightBottom.dx, pRightBottom.dy)
      ..close();
    paint.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFFFD600), Color(0xFFFF9100)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(yellowPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
