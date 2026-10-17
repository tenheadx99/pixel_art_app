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

  @override
  void initState() {
    super.initState();
    final storage = context.read<LocalStorageService>();
    _service = PromotedAppsService(storage);
    _loadApps();
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
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        _buildHeaderBanner(isDark, flavor),
                        const SizedBox(height: 18),
                        ...List.generate(
                          _apps!.length,
                          (index) => _buildAppCard(_apps![index], isDark, flavor),
                        ),
                      ],
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
                      child: _buildAppIcon(app.iconUrl),
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
              // Action Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [flavor.primary, flavor.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: flavor.primary.withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'GET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
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

  Widget _buildAppIcon(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) {
      return _buildFallbackIcon();
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      );
    }
    return Image.asset(
      trimmed,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(
        Icons.apps_rounded,
        color: Colors.white54,
        size: 32,
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
