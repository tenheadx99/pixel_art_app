import 'dart:ui' show Color;
import '../../config/app_constants.dart';

class PixelArt {
  final String id;
  final String name;
  final int gridWidth;
  final int gridHeight;
  final List<List<int>> grid;
  final Map<int, Color> colorMap;
  final String thumbnailPath;
  final String category;
  final int difficulty;
  final bool isPremium;

  /// Per-artwork diamond cost configured by admin (null = default 100).
  final int? diamondCost;

  /// Effective unlock cost in diamonds (per-artwork admin value, defaulting to 100).
  int get unlockDiamondCost => (diamondCost != null && diamondCost! > 0)
      ? diamondCost!
      : AppConstants.diamondCostUnlockArt;

  /// Seasonal availability window, set by the admin panel on remote artworks
  /// only (null = always available). Bundled artworks never carry these.
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  /// Uniform split layout for large artworks (1x1 = not split). A split
  /// artwork is colored one tile at a time; grid dims must divide evenly.
  final int partsX;
  final int partsY;

  PixelArt({
    required this.id,
    required this.name,
    required this.gridWidth,
    required this.gridHeight,
    required this.grid,
    required this.colorMap,
    this.thumbnailPath = '',
    this.category = 'General',
    this.difficulty = 1,
    this.isPremium = false,
    this.diamondCost,
    this.availableFrom,
    this.availableUntil,
    this.partsX = 1,
    this.partsY = 1,
  });

  int get totalCells => gridWidth * gridHeight;

  bool get isSplit => partsX > 1 || partsY > 1;
  int get partCount => partsX * partsY;
  int get partWidth => gridWidth ~/ partsX;
  int get partHeight => gridHeight ~/ partsY;

  // Grid-derived values are cached: these are hit on every palette/card
  // rebuild, and rescanning a 128x128 grid each time is a 16k-cell loop.
  late final int fillableCells = _scanGrid().$1;
  late final Set<int> usedNumbers = _scanGrid().$2;
  late final List<int> sortedNumbers = List.unmodifiable(
    usedNumbers.toList()..sort(),
  );

  int get colorCount => usedNumbers.length;

  (int, Set<int>) _scanGrid() {
    int count = 0;
    final numbers = <int>{};
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) {
          count++;
          numbers.add(cell);
        }
      }
    }
    return (count, numbers);
  }

  int numberAt(int row, int col) {
    if (row < 0 || row >= gridHeight || col < 0 || col >= gridWidth) return 0;
    return grid[row][col];
  }

  Color? colorForNumber(int number) => colorMap[number];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gridWidth': gridWidth,
      'gridHeight': gridHeight,
      'grid': grid.map((row) => row.join(',')).join(';'),
      'colorMap': colorMap.map((k, v) => MapEntry(k.toString(), v.toARGB32())),
      'category': category,
      'difficulty': difficulty,
      'isPremium': isPremium,
      if (diamondCost != null && diamondCost! > 0) 'diamondCost': diamondCost,
      if (availableFrom != null)
        'availableFrom': availableFrom!.toIso8601String(),
      if (availableUntil != null)
        'availableUntil': availableUntil!.toIso8601String(),
      if (partsX > 1 || partsY > 1) ...{'partsX': partsX, 'partsY': partsY},
    };
  }

  /// Copy with admin-overridden metadata (grid data is never overridden).
  PixelArt copyWith({String? category, bool? isPremium, int? diamondCost}) {
    return PixelArt(
      id: id,
      name: name,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      grid: grid,
      colorMap: colorMap,
      thumbnailPath: thumbnailPath,
      category: category ?? this.category,
      difficulty: difficulty,
      isPremium: isPremium ?? this.isPremium,
      diamondCost: diamondCost ?? this.diamondCost,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      partsX: partsX,
      partsY: partsY,
    );
  }

  factory PixelArt.fromJson(Map<String, dynamic> json) {
    final gridStr = json['grid'] as String;
    final rows = gridStr.split(';');
    final grid = rows
        .map((row) => row.split(',').map(int.parse).toList())
        .toList();

    // Everything downstream (painters, cell index, split slicing) indexes
    // grid[r][c] bounded by the *declared* dims — a doc whose grid string
    // disagrees with gridWidth/gridHeight (e.g. transposed by a hand-edited
    // Firestore doc) would RangeError on every frame. Reject it here so the
    // callers' existing try/catch guards drop it like any malformed doc.
    final width = (json['gridWidth'] as num).toInt();
    final height = (json['gridHeight'] as num).toInt();
    if (grid.length != height || grid.any((row) => row.length != width)) {
      throw FormatException(
        'grid is ${grid.length} rows but gridWidth/gridHeight say '
        '${width}x$height',
      );
    }

    final colorMapRaw = json['colorMap'] as Map<String, dynamic>;
    final colorMap = colorMapRaw.map(
      (k, v) => MapEntry(int.parse(k), Color(int.parse(v.toString()))),
    );

    return PixelArt(
      id: json['id'] as String,
      name: json['name'] as String,
      gridWidth: width,
      gridHeight: height,
      grid: grid,
      colorMap: colorMap,
      category: json['category'] as String? ?? 'General',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      isPremium: json['isPremium'] as bool? ?? false,
      diamondCost: (json['diamondCost'] as num?)?.toInt(),
      availableFrom: DateTime.tryParse(json['availableFrom'] as String? ?? ''),
      availableUntil: DateTime.tryParse(json['availableUntil'] as String? ?? ''),
      partsX: (json['partsX'] as num?)?.toInt() ?? 1,
      partsY: (json['partsY'] as num?)?.toInt() ?? 1,
    );
  }
}
