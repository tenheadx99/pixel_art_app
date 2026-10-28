import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pixel_art_app/config/flavor.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/data/services/analytics_service.dart';

/// Modal bottom sheet and preview widget that renders a vertical 9:16 share card
/// tailored for WhatsApp Status, Instagram Stories, and social sharing.
class StoryCardSheet extends StatefulWidget {
  final PixelArt art;
  final Uint8List artworkPngBytes;
  final Duration completionDuration;
  final DateTime completionDate;

  const StoryCardSheet({
    super.key,
    required this.art,
    required this.artworkPngBytes,
    required this.completionDuration,
    required this.completionDate,
  });

  /// Helper to display the story card sheet.
  static Future<void> show(
    BuildContext context, {
    required PixelArt art,
    required Uint8List artworkPngBytes,
    required Duration completionDuration,
    required DateTime completionDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoryCardSheet(
        art: art,
        artworkPngBytes: artworkPngBytes,
        completionDuration: completionDuration,
        completionDate: completionDate,
      ),
    );
  }

  @override
  State<StoryCardSheet> createState() => _StoryCardSheetState();
}

class _StoryCardSheetState extends State<StoryCardSheet> {
  final GlobalKey _cardRepaintKey = GlobalKey();
  bool _isSharing = false;

  String get _timeFormatted {
    final mins = widget.completionDuration.inMinutes;
    final secs = widget.completionDuration.inSeconds % 60;
    if (mins < 1) return '${secs}s';
    return '${mins}m ${secs}s';
  }

  String get _dateFormatted {
    return DateFormat('d MMMM yyyy').format(widget.completionDate);
  }

  Future<void> _shareStoryCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // 1. Capture the RepaintBoundary as a crisp high-res 1080x1920 PNG
      final boundary = _cardRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Render boundary not ready');
      }

      // pixelRatio 3.0 gives ultra-sharp 1080x1920 resolution from 360x640 logical size
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null) {
        throw Exception('Failed to encode PNG');
      }

      // 2. Write to temp file
      final tempDir = await getTemporaryDirectory();
      final shareFile = File(
        '${tempDir.path}/story_${widget.art.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await shareFile.writeAsBytes(pngBytes);

      // 3. Analytics
      AnalyticsService().logArtworkShared(
        artId: widget.art.id,
        format: 'story_card_9_16',
        title: widget.art.name,
        flavor: currentFlavor.name,
      );

      // 4. Share via SharePlus
      final appName = FlavorConfig.current.appName;
      final textMessage =
          'I just finished "${widget.art.name}" in $appName! 🎨✨\nGet the app on Google Play!';

      await Share.shareXFiles(
        [XFile(shareFile.path, mimeType: 'image/png')],
        text: textMessage,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate story card. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flavor = FlavorConfig.current;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: flavor.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: flavor.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Status & Story',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vertical 9:16 card for WhatsApp & Instagram',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Live 9:16 Card Preview
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: flavor.primary.withAlpha(50),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _cardRepaintKey,
                        child: SizedBox(
                          width: 360,
                          height: 640,
                          child: _build9x16Card(flavor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // One-tap Main WhatsApp & Story Share Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSharing ? null : () => _shareStoryCard(),
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      shadowColor: const Color(0xFF25D366).withAlpha(120),
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSharing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Share to WhatsApp Status & Story',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the exact 9:16 aesthetic card layout
  Widget _build9x16Card(FlavorConfig flavor) {
    final gradientColors = flavor.brandGradient.length >= 2
        ? flavor.brandGradient
        : [flavor.primary, flavor.secondary];

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF100C1A), // Rich cosmic dark top
            gradientColors[0].withAlpha(180),
            gradientColors[1].withAlpha(220),
            const Color(0xFF090610), // Deep bottom
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Ambient decorative sparkles / soft blur circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: flavor.accent.withAlpha(50),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: flavor.primary.withAlpha(60),
              ),
            ),
          ),

          // Main Content Layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Header: App Branding + Completion Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withAlpha(50),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            color: flavor.accent,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            flavor.appName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Date Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dateFormatted,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // Artwork Headline / Title
                Text(
                  widget.art.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MASTERPIECE COMPLETED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: flavor.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Center Artwork Canvas with Dual Glow Frame
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 240,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(140),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: flavor.primary.withAlpha(80),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withAlpha(70),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.memory(
                      widget.artworkPngBytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Stats Pills (Time, Colors, 100%)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildStatPill(
                      icon: Icons.timer_outlined,
                      label: _timeFormatted,
                    ),
                    _buildStatPill(
                      icon: Icons.color_lens_outlined,
                      label: '${widget.art.colorCount} Colors',
                    ),
                    _buildStatPill(
                      icon: Icons.check_circle_outline_rounded,
                      label: '100% Done',
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Bottom Watermark & Call To Action
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: flavor.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.brush_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Colored with ${flavor.appName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Get free on Google Play Store',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(160),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withAlpha(40),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
