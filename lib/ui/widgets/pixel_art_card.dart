import 'package:flutter/material.dart';
import '../../data/models/pixel_art.dart';
import '../theme/app_style.dart';
import 'art_preview_painter.dart';
import 'pressable.dart';

class PixelArtCard extends StatelessWidget {
  final PixelArt art;
  final int index;
  final bool isCompleted;
  final bool isFavorite;
  final bool isUnlocked;
  final int progressPercent;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const PixelArtCard({
    super.key,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: art.name,
      button: true,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.black.withAlpha(10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                // 1. Full-Bleed Artwork Canvas
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF222433), const Color(0xFF191A26)]
                            : [const Color(0xFFF7F8FA), const Color(0xFFECEFF5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Hero(
                      tag: 'art_canvas_${art.id}_$index',
                      child: RepaintBoundary(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: art.gridWidth.toDouble(),
                            height: art.gridHeight.toDouble(),
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
                  ),
                ),

                // 2. Bottom Gradient Scrim & Meta Overlay (Idea 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.40),
                          Colors.black.withOpacity(0.72),
                        ],
                        stops: const [0.0, 0.15, 0.55, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildColorPaletteChip(context),
                        _buildGridSizeChip(context),
                      ],
                    ),
                  ),
                ),

                // 3. Locked Overlay
                if (!isUnlocked)
                  Positioned.fill(
                    child: Container(
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
                  ),
              // Top-left status & tag badges
              Positioned(
                top: 8,
                left: 8,
                right: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUnlocked) ...[
                      const Icon(
                        Icons.workspace_premium,
                        color: Color(0xFFFFD54F),
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (_inProgress) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C5CE7).withAlpha(90),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.brush_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$progressPercent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                          ),
                          borderRadius: BorderRadius.circular(10),
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
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (art.tag != null && art.tag!.trim().isNotEmpty)
                      Flexible(child: _buildTagBadge(context)),
                  ],
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
                          ? (isDark ? Colors.red.withAlpha(40) : const Color(0xFFFFECEC))
                          : (isDark ? Colors.black.withAlpha(100) : Colors.white.withAlpha(220)),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 40 : 15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(isFavorite),
                        color: isFavorite ? const Color(0xFFFF4757) : (isDark ? Colors.white70 : Colors.black54),
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
    ),
  );
}

  Widget _buildTagBadge(BuildContext context) {
    final rawTag = art.tag!.trim();
    final tagUpper = rawTag.toUpperCase();

    final (List<Color> gradient, IconData icon) = switch (tagUpper) {
      'NEW' => (
          [const Color(0xFF00C6FF), const Color(0xFF0072FF)],
          Icons.auto_awesome_rounded,
        ),
      'POPULAR' => (
          [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
          Icons.local_fire_department_rounded,
        ),
      'HOT' => (
          [const Color(0xFFFF0844), const Color(0xFFFFB199)],
          Icons.whatshot_rounded,
        ),
      'TRENDING' => (
          [const Color(0xFF8A2387), const Color(0xFFE94057)],
          Icons.trending_up_rounded,
        ),
      _ => (
          [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)],
          Icons.label_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withAlpha(100),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              tagUpper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPaletteChip(BuildContext context) {
    final maxDots = art.sortedNumbers.length > 3 ? 3 : art.sortedNumbers.length;
    final extraColors = art.colorCount - maxDots;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(maxDots, (i) {
            final num = art.sortedNumbers[i];
            final color =
                art.colorForNumber(num) ?? AppStyle.numberToColor(num);
            return Align(
              widthFactor: 0.70,
              child: Container(
                width: 12.5,
                height: 12.5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.90),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }),
          if (extraColors > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '+$extraColors',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridSizeChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.grid_on_rounded,
            size: 11,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 3.5),
          Text(
            '${art.gridWidth}×${art.gridHeight}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

