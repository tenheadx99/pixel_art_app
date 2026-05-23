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

  const PixelArt({
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
  });

  int get totalCells => gridWidth * gridHeight;

  int get fillableCells {
    int count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) count++;
      }
    }
    return count;
  }

  Set<int> get usedNumbers {
    final numbers = <int>{};
    for (final row in grid) {
      for (final cell in row) {
        if (cell > 0) numbers.add(cell);
      }
    }
    return numbers;
  }

  int get colorCount => usedNumbers.length;

  List<int> get sortedNumbers => usedNumbers.toList()..sort();

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
    );
  }
}
