import 'dart:ui' show Color;

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

  /// Optional availability window for admin-published seasonal/limited art
  /// (bundled artworks always have null = always available).
  final DateTime? availableFrom;
  final DateTime? availableUntil;

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
    this.availableFrom,
    this.availableUntil,
  });

  /// True while [now] is inside the availability window (if any).
  bool isAvailableAt(DateTime now) {
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableUntil != null && now.isAfter(availableUntil!)) return false;
    return true;
  }

  /// True when this is a time-limited piece that is still available — the
  /// gallery shows a "Limited" badge for these.
  bool get isLimited =>
      availableUntil != null && !DateTime.now().isAfter(availableUntil!);

  int get totalCells => gridWidth * gridHeight;

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

  /// Grid data is shared by reference — admin overrides only touch metadata.
  PixelArt copyWith({
    String? name,
    String? category,
    int? difficulty,
    bool? isPremium,
  }) {
    return PixelArt(
      id: id,
      name: name ?? this.name,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      grid: grid,
      colorMap: colorMap,
      thumbnailPath: thumbnailPath,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      isPremium: isPremium ?? this.isPremium,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
    );
  }

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
      if (availableFrom != null)
        'availableFrom': availableFrom!.toIso8601String(),
      if (availableUntil != null)
        'availableUntil': availableUntil!.toIso8601String(),
    };
  }

  factory PixelArt.fromJson(Map<String, dynamic> json) {
    final gridStr = json['grid'] as String;
    final rows = gridStr.split(';');
    final grid = rows
        .map((row) => row.split(',').map(int.parse).toList())
        .toList();

    final colorMapRaw = json['colorMap'] as Map<String, dynamic>;
    final colorMap = colorMapRaw.map(
      (k, v) => MapEntry(int.parse(k), Color(int.parse(v.toString()))),
    );

    return PixelArt(
      id: json['id'] as String,
      name: json['name'] as String,
      gridWidth: json['gridWidth'] as int,
      gridHeight: json['gridHeight'] as int,
      grid: grid,
      colorMap: colorMap,
      category: json['category'] as String? ?? 'General',
      difficulty: json['difficulty'] as int? ?? 1,
      isPremium: json['isPremium'] as bool? ?? false,
      availableFrom: DateTime.tryParse(json['availableFrom'] as String? ?? ''),
      availableUntil:
          DateTime.tryParse(json['availableUntil'] as String? ?? ''),
    );
  }
}
