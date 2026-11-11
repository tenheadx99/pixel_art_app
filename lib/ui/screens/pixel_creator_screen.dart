import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/pixel_art.dart';
import '../../data/services/database_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/screenshot_service.dart';
import '../../providers/app_settings_provider.dart';
import '../../ui/widgets/ad_banner.dart';
import '../../ui/widgets/transitions.dart';
import 'coloring_screen.dart';

enum CreatorTool { pencil, bucket, eraser, eyedropper }

/// A full-featured Pixel Art Creator and Blank Canvas editor.
/// Allows freehand drawing, flood filling, erasing, custom palettes,
/// and converting creations into playable Color-by-Number puzzles.
class PixelCreatorScreen extends StatefulWidget {
  final String title;
  final int size;
  final String paletteStyle;

  const PixelCreatorScreen({
    super.key,
    this.title = 'My Creation',
    this.size = 24,
    this.paletteStyle = 'retro',
  });

  @override
  State<PixelCreatorScreen> createState() => _PixelCreatorScreenState();
}

class _PixelCreatorScreenState extends State<PixelCreatorScreen> {
  late String _artName;
  late int _gridSize;
  late List<List<int>> _grid; // 0 = empty, 1..N = color index
  late Map<int, Color> _palette;
  int _selectedColorIndex = 1;
  CreatorTool _currentTool = CreatorTool.pencil;
  bool _showGridLines = true;

  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  // Undo / Redo history
  final List<List<List<int>>> _undoStack = [];
  final List<List<List<int>>> _redoStack = [];

  // Single-finger vs pan tracking
  int _activePointers = 0;
  bool _isDrawing = false;
  int? _lastDrawnRow;
  int? _lastDrawnCol;

  @override
  void initState() {
    super.initState();
    _artName = widget.title;
    _gridSize = widget.size.clamp(12, 64);
    _grid = List.generate(
      _gridSize,
      (_) => List<int>.filled(_gridSize, 0),
    );
    _palette = _buildInitialPalette(widget.paletteStyle);
    _selectedColorIndex = 1;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Map<int, Color> _buildInitialPalette(String style) {
    switch (style.toLowerCase()) {
      case 'pastel':
        return {
          1: const Color(0xFFFFB3BA),
          2: const Color(0xFFFFDFBA),
          3: const Color(0xFFFFFFBA),
          4: const Color(0xFFBAFFC9),
          5: const Color(0xFFBAE1FF),
          6: const Color(0xFFE8BAFF),
          7: const Color(0xFFFFFFFF),
          8: const Color(0xFF4A4A4A),
        };
      case 'vibrant':
        return {
          1: const Color(0xFFFF1744),
          2: const Color(0xFFFF9100),
          3: const Color(0xFFFFEA00),
          4: const Color(0xFF00E676),
          5: const Color(0xFF00B0FF),
          6: const Color(0xFFD500F9),
          7: const Color(0xFF212121),
          8: const Color(0xFFFFFFFF),
        };
      case 'retro':
      default:
        return {
          1: const Color(0xFF000000),
          2: const Color(0xFFFFFFFF),
          3: const Color(0xFFE71D36),
          4: const Color(0xFFFF9F1C),
          5: const Color(0xFFFFE066),
          6: const Color(0xFF2EC4B6),
          7: const Color(0xFF011627),
          8: const Color(0xFF7209B7),
          9: const Color(0xFF4CC9F0),
          10: const Color(0xFF8D5B4C),
        };
    }
  }

  void _pushUndo() {
    final snapshot = _grid.map((row) => List<int>.from(row)).toList();
    _undoStack.add(snapshot);
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    _redoStack.add(_grid.map((row) => List<int>.from(row)).toList());
    setState(() {
      _grid = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    _undoStack.add(_grid.map((row) => List<int>.from(row)).toList());
    setState(() {
      _grid = _redoStack.removeLast();
    });
  }

  void _applyTool(int row, int col) {
    if (row < 0 || row >= _gridSize || col < 0 || col >= _gridSize) return;

    switch (_currentTool) {
      case CreatorTool.pencil:
        if (_grid[row][col] == _selectedColorIndex) return;
        _grid[row][col] = _selectedColorIndex;
        HapticFeedback.selectionClick();
        setState(() {});
        break;

      case CreatorTool.eraser:
        if (_grid[row][col] == 0) return;
        _grid[row][col] = 0;
        HapticFeedback.selectionClick();
        setState(() {});
        break;

      case CreatorTool.bucket:
        _floodFill(row, col, _selectedColorIndex);
        HapticFeedback.mediumImpact();
        setState(() {});
        break;

      case CreatorTool.eyedropper:
        final picked = _grid[row][col];
        if (picked > 0 && _palette.containsKey(picked)) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedColorIndex = picked;
            _currentTool = CreatorTool.pencil;
          });
        }
        break;
    }
  }

  void _floodFill(int startR, int startC, int newColor) {
    final targetColor = _grid[startR][startC];
    if (targetColor == newColor) return;

    final queue = Queue<(int, int)>();
    queue.add((startR, startC));
    _grid[startR][startC] = newColor;

    const dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)];

    while (queue.isNotEmpty) {
      final (r, c) = queue.removeFirst();
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 &&
            nr < _gridSize &&
            nc >= 0 &&
            nc < _gridSize &&
            _grid[nr][nc] == targetColor) {
          _grid[nr][nc] = newColor;
          queue.add((nr, nc));
        }
      }
    }
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Canvas?'),
        content: const Text('All your drawings on this canvas will be reset.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pushUndo();
              setState(() {
                _grid = List.generate(
                  _gridSize,
                  (_) => List<int>.filled(_gridSize, 0),
                );
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addNewColor() {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = [
          const Color(0xFFFF5252),
          const Color(0xFFFF4081),
          const Color(0xFFE040FB),
          const Color(0xFF7C4DFF),
          const Color(0xFF536DFE),
          const Color(0xFF448AFF),
          const Color(0xFF18FFFF),
          const Color(0xFF64FFDA),
          const Color(0xFF69F0AE),
          const Color(0xFFB2FF59),
          const Color(0xFFEEFF41),
          const Color(0xFFFFD740),
          const Color(0xFFFFAB40),
          const Color(0xFFFF6E40),
          const Color(0xFF8D6E63),
          const Color(0xFFB0BEC5),
          const Color(0xFF37474F),
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        ];

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Color to Palette'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors.map((c) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    final nextIndex = _palette.isEmpty
                        ? 1
                        : (_palette.keys.reduce(math.max) + 1);
                    _palette[nextIndex] = c;
                    _selectedColorIndex = nextIndex;
                  });
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26, width: 1.5),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Converts the user's drawing into a PixelArt object ready for coloring.
  PixelArt _compilePixelArt() {
    // Map used colors to clean 1..N indices
    final usedOldIndices = <int>{};
    for (final row in _grid) {
      for (final cell in row) {
        if (cell > 0) usedOldIndices.add(cell);
      }
    }

    final sortedUsed = usedOldIndices.toList()..sort();
    final remap = <int, int>{};
    final newColorMap = <int, Color>{};

    for (var i = 0; i < sortedUsed.length; i++) {
      final oldIdx = sortedUsed[i];
      final newIdx = i + 1;
      remap[oldIdx] = newIdx;
      newColorMap[newIdx] = _palette[oldIdx] ?? Colors.black;
    }

    final newGrid = List.generate(
      _gridSize,
      (r) => List.generate(
        _gridSize,
        (c) => remap[_grid[r][c]] ?? 0,
      ),
    );

    // If canvas is completely empty, give at least one sample pixel so coloring screen works
    if (newColorMap.isEmpty) {
      newColorMap[1] = const Color(0xFF6C5CE7);
      newGrid[0][0] = 1;
    }

    return PixelArt(
      id: 'user_art_${DateTime.now().millisecondsSinceEpoch}',
      name: _artName.trim().isNotEmpty ? _artName.trim() : 'My Pixel Art',
      gridWidth: _gridSize,
      gridHeight: _gridSize,
      grid: newGrid,
      colorMap: newColorMap,
      category: 'Custom',
      difficulty: math.max(1, _gridSize ~/ 8),
      isPremium: false,
    );
  }

  void _playAsColorByNumber() {
    final art = _compilePixelArt();
    Navigator.pushReplacement(
      context,
      fadeThroughRoute(
        ColoringScreen(art: art),
        name: 'coloring',
      ),
    );
  }

  Future<void> _saveDirectlyToGallery() async {
    try {
      final storage = context.read<LocalStorageService>();
      final database = context.read<DatabaseService>();
      final screenshotService = ScreenshotService(storage);

      final pngBytes = await screenshotService.captureAsPng(_repaintKey);
      if (pngBytes == null) throw Exception('Capture failed');

      final path = await screenshotService.saveArtwork(pngBytes, _artName);
      if (path == null) throw Exception('Save failed');

      final art = _compilePixelArt();
      await database.saveArtwork({
        'id': art.id,
        'pixel_art_id': art.id,
        'name': art.name,
        'file_path': path,
        'date_created': DateTime.now().toIso8601String(),
        'completion_percent': 100,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to your Gallery! 🎨'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF00B894),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsProvider? settings;
    try {
      settings = context.watch<AppSettingsProvider>();
    } catch (_) {
      settings = null;
    }
    final isPro = settings?.isProUser ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF6C5CE7);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13131F) : const Color(0xFFF7F7FA),
      bottomNavigationBar: isPro
          ? null
          : const SafeArea(child: AdBanner()),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1B1B2C) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            final controller = TextEditingController(text: _artName);
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Artwork Name'),
                content: TextField(controller: controller, autofocus: true),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _artName = controller.text);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _artName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            onPressed: _undoStack.isNotEmpty ? _undo : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            onPressed: _redoStack.isNotEmpty ? _redo : null,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: Icon(
              _showGridLines ? Icons.grid_on_rounded : Icons.grid_off_rounded,
              color: _showGridLines ? primary : Colors.grey,
            ),
            onPressed: () => setState(() => _showGridLines = !_showGridLines),
            tooltip: 'Toggle Grid',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _clearCanvas,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Interactive Drawing Canvas
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double canvasSide = math.min(
                  constraints.maxWidth - 24,
                  constraints.maxHeight - 24,
                );
                final double cellSize = canvasSide / _gridSize;

                return Center(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.9,
                    maxScale: 5.0,
                    panEnabled: _activePointers > 1, // 2 fingers to pan/zoom
                    child: Listener(
                      onPointerDown: (e) {
                        _activePointers++;
                        if (_activePointers == 1) {
                          _pushUndo();
                          _isDrawing = true;
                          final pos = _cellAtPos(e.localPosition, cellSize);
                          if (pos != null) {
                            _lastDrawnRow = pos.$1;
                            _lastDrawnCol = pos.$2;
                            _applyTool(pos.$1, pos.$2);
                          }
                        }
                      },
                      onPointerMove: (e) {
                        if (_isDrawing && _activePointers == 1) {
                          final pos = _cellAtPos(e.localPosition, cellSize);
                          if (pos != null &&
                              (pos.$1 != _lastDrawnRow || pos.$2 != _lastDrawnCol)) {
                            _lastDrawnRow = pos.$1;
                            _lastDrawnCol = pos.$2;
                            _applyTool(pos.$1, pos.$2);
                          }
                        }
                      },
                      onPointerUp: (e) {
                        _activePointers = math.max(0, _activePointers - 1);
                        if (_activePointers == 0) {
                          _isDrawing = false;
                          _lastDrawnRow = null;
                          _lastDrawnCol = null;
                        }
                      },
                      onPointerCancel: (_) {
                        _activePointers = 0;
                        _isDrawing = false;
                      },
                      child: Container(
                        width: canvasSide,
                        height: canvasSide,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2C)
                              : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: CustomPaint(
                              size: Size(canvasSide, canvasSide),
                              painter: _PixelCanvasPainter(
                                grid: _grid,
                                palette: _palette,
                                showGridLines: _showGridLines,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Tool Dock (Pencil, Bucket, Eraser, Eyedropper)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B2C) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToolButton(CreatorTool.pencil, Icons.brush_rounded, 'Draw'),
                const SizedBox(width: 14),
                _buildToolButton(CreatorTool.bucket, Icons.format_color_fill_rounded, 'Fill'),
                const SizedBox(width: 14),
                _buildToolButton(CreatorTool.eraser, Icons.auto_fix_normal_rounded, 'Erase'),
                const SizedBox(width: 14),
                _buildToolButton(CreatorTool.eyedropper, Icons.colorize_rounded, 'Pick'),
              ],
            ),
          ),

          // 3. Color Palette Swatches
          Container(
            height: 64,
            color: isDark ? const Color(0xFF181826) : const Color(0xFFF0F0F4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                ..._palette.entries.map((entry) {
                  final idx = entry.key;
                  final color = entry.value;
                  final isSelected = _selectedColorIndex == idx &&
                      _currentTool != CreatorTool.eraser;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedColorIndex = idx;
                        if (_currentTool == CreatorTool.eraser) {
                          _currentTool = CreatorTool.pencil;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: isSelected ? 44 : 38,
                      height: isSelected ? 44 : 38,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? primary : Colors.black26,
                          width: isSelected ? 3.0 : 1.2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: primary.withAlpha(90),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: isSelected
                          ? Center(
                              child: Icon(
                                Icons.check,
                                size: 18,
                                color: color.computeLuminance() > 0.45
                                    ? Colors.black87
                                    : Colors.white,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
                // Add Color Button
                GestureDetector(
                  onTap: _addNewColor,
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white12 : Colors.black12,
                      border: Border.all(color: Colors.grey.withAlpha(60)),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // 4. Action Row (Play Color-By-Number & Save Gallery)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            color: isDark ? const Color(0xFF1B1B2C) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveDirectlyToGallery,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: const Text('Save Art'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _playAsColorByNumber,
                    icon: const Icon(Icons.colorize_rounded, size: 18),
                    label: const Text('Play Color by Number'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 3,
                      shadowColor: primary.withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  Widget _buildToolButton(CreatorTool tool, IconData icon, String label) {
    final isSelected = _currentTool == tool;
    final primary = const Color(0xFF6C5CE7);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTool = tool);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? primary : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (int, int)? _cellAtPos(Offset localPos, double cellSize) {
    if (cellSize <= 0) return null;
    final c = (localPos.dx / cellSize).floor();
    final r = (localPos.dy / cellSize).floor();
    if (r >= 0 && r < _gridSize && c >= 0 && c < _gridSize) {
      return (r, c);
    }
    return null;
  }
}

class _PixelCanvasPainter extends CustomPainter {
  final List<List<int>> grid;
  final Map<int, Color> palette;
  final bool showGridLines;
  final bool isDark;

  _PixelCanvasPainter({
    required this.grid,
    required this.palette,
    required this.showGridLines,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int h = grid.length;
    final int w = grid[0].length;
    final double cw = size.width / w;
    final double ch = size.height / h;

    final cellPaint = Paint()..style = PaintingStyle.fill;
    final gridLinePaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw painted cells
    for (var r = 0; r < h; r++) {
      for (var c = 0; c < w; c++) {
        final colorIdx = grid[r][c];
        if (colorIdx > 0 && palette.containsKey(colorIdx)) {
          cellPaint.color = palette[colorIdx]!;
          canvas.drawRect(
            Rect.fromLTWH(c * cw, r * ch, cw, ch),
            cellPaint,
          );
        }
      }
    }

    // Draw grid lines
    if (showGridLines) {
      for (var r = 0; r <= h; r++) {
        canvas.drawLine(
          Offset(0, r * ch),
          Offset(size.width, r * ch),
          gridLinePaint,
        );
      }
      for (var c = 0; c <= w; c++) {
        canvas.drawLine(
          Offset(c * cw, 0),
          Offset(c * cw, size.height),
          gridLinePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelCanvasPainter old) => true;
}
