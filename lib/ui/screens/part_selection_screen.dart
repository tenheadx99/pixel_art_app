import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/pixel_art.dart';
import '../../data/models/split_art.dart';
import '../../data/models/user_artwork.dart';
import '../../data/services/database_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/screenshot_service.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/gallery_provider.dart';
import '../widgets/art_preview_painter.dart';
import '../motion.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'coloring_screen.dart';

/// Part picker for a split artwork: the full piece is shown with a tile
/// overlay, each tile colored on its own small canvas. Once every tile is
/// done the tiles merge into the finished artwork with a one-time reveal.
class PartSelectionScreen extends StatefulWidget {
  final PixelArt parent;

  const PartSelectionScreen({super.key, required this.parent});

  @override
  State<PartSelectionScreen> createState() => _PartSelectionScreenState();
}

class _PartSelectionScreenState extends State<PartSelectionScreen>
    with SingleTickerProviderStateMixin {
  late List<int> _partPcts;
  late List<int> _partFillables;
  List<List<bool>>? _filledMask;
  bool _revealed = false;

  late final AnimationController _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final Animation<double> _revealFade = CurvedAnimation(
    parent: _revealController,
    curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
  );

  String get _revealedPrefKey => 'split_revealed_${widget.parent.id}';

  @override
  void initState() {
    super.initState();
    _partFillables = SplitArt.partFillableCounts(widget.parent);
    _revealed = context.read<LocalStorageService>().getBool(_revealedPrefKey);
    _refresh();
    if (_revealed) _revealController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReveal());
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  /// Re-reads per-part progress and rebuilds the fill mask (cheap: 9 prefs
  /// ints plus one grid-string parse per in-progress part).
  void _refresh() {
    final gallery = context.read<GalleryProvider>();
    final storage = context.read<LocalStorageService>();
    final parent = widget.parent;
    _partPcts = [
      for (int i = 0; i < parent.partCount; i++)
        gallery.partProgressPercent(parent, i),
    ];
    final mask = List.generate(
      parent.gridHeight,
      (_) => List<bool>.filled(parent.gridWidth, false),
    );
    for (int i = 0; i < parent.partCount; i++) {
      if (_partFillables[i] == 0) continue; // nothing drawable in the tile
      if (_partPcts[i] >= 100) {
        _maskTile(mask, i, null);
      } else if (_partPcts[i] > 0) {
        final raw = storage.getString(
          'pixelart_progress_${SplitArt.partId(parent.id, i)}',
        );
        if (raw.isEmpty) continue;
        final rows = raw.split(';');
        if (rows.length != parent.partHeight) continue;
        final filled = rows
            .map((r) => r.split(',').map((v) => int.tryParse(v) ?? 0).toList())
            .toList();
        if (filled.any((r) => r.length != parent.partWidth)) continue;
        _maskTile(mask, i, filled);
      }
    }
    _filledMask = mask;
  }

  /// Marks tile [index] of the mask: fully true when [filled] is null,
  /// otherwise true where the part's saved grid has a color.
  void _maskTile(List<List<bool>> mask, int index, List<List<int>>? filled) {
    final parent = widget.parent;
    final row0 = (index ~/ parent.partsX) * parent.partHeight;
    final col0 = (index % parent.partsX) * parent.partWidth;
    for (int r = 0; r < parent.partHeight; r++) {
      for (int c = 0; c < parent.partWidth; c++) {
        mask[row0 + r][col0 + c] = filled == null || filled[r][c] > 0;
      }
    }
  }

  void _openPart(int index) {
    Navigator.push(
      context,
      fadeThroughRoute(
        ChangeNotifierProvider.value(
          value: context.read<ColoringProvider>(),
          child: ColoringScreen(art: SplitArt.partOf(widget.parent, index)),
        ),
        name: 'coloring',
      ),
    ).then((_) {
      if (!mounted) return;
      setState(_refresh);
      _maybeReveal();
    });
  }

  /// Plays the one-time merge reveal (and saves the merged artwork) once the
  /// last part is finished.
  void _maybeReveal() {
    if (_revealed || !mounted) return;
    final gallery = context.read<GalleryProvider>();
    if (!gallery.partsAllComplete(widget.parent)) return;
    _revealed = true;
    context.read<LocalStorageService>().setBool(_revealedPrefKey, true);
    setState(() {});
    _revealController.forward();
    _saveMergedArtwork();
  }

  /// Exports the finished full artwork as a PNG into My Works — the merged
  /// counterpart of ColoringScreen._saveArtwork, rendered offscreen because
  /// no single canvas ever held the whole grid.
  Future<void> _saveMergedArtwork() async {
    final storageService = context.read<LocalStorageService>();
    final databaseService = context.read<DatabaseService>();
    final pngBytes = await renderArtPng(widget.parent);
    if (pngBytes == null) return;
    final screenshotService = ScreenshotService(storageService);
    final path = await screenshotService.saveArtwork(
      pngBytes,
      widget.parent.name,
    );
    if (path == null) return;
    await databaseService.saveArtwork(
      UserArtwork(
        id: const Uuid().v4(),
        pixelArtId: widget.parent.id,
        name: widget.parent.name,
        filePath: path,
        dateCreated: DateTime.now(),
        completionPercent: 100,
      ).toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final done = _partPcts.where((p) => p >= 100).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(parent.name),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              _revealed
                  ? 'Completed — all parts merged!'
                  : 'Pick a part to color · $done/${parent.partCount} done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AspectRatio(
                    aspectRatio: parent.gridWidth / parent.gridHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: ArtPreviewPainter(
                                  art: parent,
                                  isCompleted: false,
                                  filledMask: _filledMask,
                                ),
                              ),
                            ),
                            FadeTransition(
                              opacity: _revealFade,
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: ArtPreviewPainter(
                                    art: parent,
                                    isCompleted: true,
                                  ),
                                ),
                              ),
                            ),
                            if (!_revealed) _buildTileOverlay(parent),
                            ConfettiOverlay(
                              animation: _revealController,
                              seed: widget.parent.id.hashCode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTileOverlay(PixelArt parent) {
    return Column(
      children: [
        for (int py = 0; py < parent.partsY; py++)
          Expanded(
            child: Row(
              children: [
                for (int px = 0; px < parent.partsX; px++)
                  Expanded(child: _buildTile(py * parent.partsX + px)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTile(int index) {
    final empty = _partFillables[index] == 0;
    final pct = _partPcts[index];
    final complete = pct >= 100;
    return PressableScale(
      onTap: empty ? null : () => _openPart(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withAlpha(120)),
        ),
        child: Center(
          child: empty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: complete
                        ? const Color(0xFF00B894)
                        : Colors.black.withAlpha(120),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Pop between the % label and the completed check instead
                  // of swapping instantly.
                  child: AnimatedSwitcher(
                    duration: Motion.base,
                    switchInCurve: Motion.settle,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: complete
                        ? const Icon(
                            Icons.check,
                            key: ValueKey('check'),
                            color: Colors.white,
                            size: 14,
                          )
                        : Text(
                            pct > 0 ? '$pct%' : '${index + 1}',
                            key: const ValueKey('label'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
        ),
      ),
    );
  }
}
