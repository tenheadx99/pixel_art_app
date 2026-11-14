import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/flavor.dart';
import '../../data/models/pixel_art.dart';
import '../../data/models/split_art.dart';
import '../../data/services/remote_config_service.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/gallery_provider.dart';
import '../theme/app_style.dart';
import '../widgets/ad_banner.dart';
import '../widgets/pixel_art_card.dart';
import '../widgets/transitions.dart';
import 'coloring_screen.dart';
import 'part_selection_screen.dart';
import 'paywall_screen.dart';

/// Screen displaying a full grid of artworks when a user taps "View all"
/// on a shelf, category, or the main listing. Shows a bottom banner ad.
class ArtworkListScreen extends StatefulWidget {
  final String title;
  final String? category;
  final List<PixelArt>? artworks;

  const ArtworkListScreen({
    super.key,
    required this.title,
    this.category,
    this.artworks,
  });

  @override
  State<ArtworkListScreen> createState() => _ArtworkListScreenState();
}

class _ArtworkListScreenState extends State<ArtworkListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PixelArt> _resolveArtworks(GalleryProvider gallery) {
    List<PixelArt> base;
    if (widget.artworks != null && widget.artworks!.isNotEmpty) {
      base = widget.artworks!;
    } else if (widget.category != null && widget.category!.isNotEmpty) {
      base = gallery.artworksForCategory(widget.category!);
    } else {
      base = gallery.catalog;
    }

    if (_searchQuery.trim().isEmpty) {
      return base;
    }

    final query = _searchQuery.trim().toLowerCase();
    return base.where((art) {
      return art.name.toLowerCase().contains(query) ||
          art.category.toLowerCase().contains(query) ||
          (art.tag != null && art.tag!.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _openColoring(PixelArt art) async {
    final gallery = context.read<GalleryProvider>();
    final settings = context.read<AppSettingsProvider>();

    if (!gallery.isUnlocked(art, settings.isProUser)) {
      _showLockedDialog(art);
      return;
    }

    gallery.noteArtworkOpened(art);

    if (art.isSplit && SplitArt.validSplit(art)) {
      await Navigator.push(
        context,
        fadeThroughRoute(
          PartSelectionScreen(parent: art),
          name: 'part_selection',
        ),
      );
      if (mounted) {
        context.read<GalleryProvider>().refresh();
      }
      return;
    }

    await Navigator.push(
      context,
      fadeThroughRoute(
        ColoringScreen(art: art),
        name: 'coloring',
      ),
    );
    if (mounted) {
      context.read<GalleryProvider>().refresh();
    }
  }

  void _showLockedDialog(PixelArt art) {
    final unlockCost = art.unlockDiamondCost;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final titleColor = isDark ? Colors.white : const Color(0xFF2A2440);
        final subColor = isDark ? Colors.white70 : Colors.black54;

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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canAfford
                            ? () {
                                if (settings.useDiamonds(unlockCost, itemName: 'artwork_unlock', artId: art.id)) {
                                  HapticFeedback.mediumImpact();
                                  context
                                      .read<GalleryProvider>()
                                      .unlockWithDiamonds(art.id, cost: unlockCost);
                                  Navigator.pop(ctx);
                                  _openColoring(art);
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              fadeThroughRoute(
                                const PaywallScreen(source: 'artwork_list'),
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
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final items = _resolveArtworks(gallery);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search artworks...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '${items.length} ${items.length == 1 ? 'artwork' : 'artworks'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 64,
                    color: Theme.of(context).hintColor.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No artworks found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final art = items[index];
                        return PixelArtCard(
                          art: art,
                          index: index,
                          isCompleted: gallery.isCompleted(art.id),
                          isFavorite: gallery.isFavorite(art.id),
                          isUnlocked: gallery.isUnlocked(art, settings.isProUser),
                          progressPercent: gallery.artProgressPercent(art),
                          onTap: () => _openColoring(art),
                          onFavorite: () => gallery.toggleFavorite(art.id),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: settings.shouldRemoveAds
          ? null
          : const SafeArea(
              top: false,
              child: AdBanner(),
            ),
    );
  }
}
