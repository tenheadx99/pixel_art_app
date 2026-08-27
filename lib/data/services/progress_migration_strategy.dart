import 'package:pixel_art_app/data/models/pixel_art.dart';

/// Strategy service for validating, versioning, and migrating artwork save progress.
class ProgressMigrationStrategy {
  static const int currentSchemaVersion = 2;

  /// Validates whether a raw saved grid string matches the target artwork dimensions.
  static bool isGridCompatible(String rawGridString, PixelArt art) {
    if (rawGridString.trim().isEmpty) return false;

    final rows = rawGridString.split(';');
    if (rows.length != art.gridHeight) return false;

    for (final row in rows) {
      final cols = row.split(',');
      if (cols.length != art.gridWidth) return false;
    }
    return true;
  }

  /// Parses and validates saved grid matrix against target artwork dimensions.
  /// Returns empty grid matrix if saved state is corrupt or incompatible.
  static List<List<int>> parseAndValidateGrid({
    required String rawGridString,
    required PixelArt art,
  }) {
    final emptyGrid = List.generate(
      art.gridHeight,
      (_) => List.filled(art.gridWidth, 0),
    );

    if (!isGridCompatible(rawGridString, art)) {
      return emptyGrid;
    }

    try {
      final rows = rawGridString.split(';');
      final parsed = <List<int>>[];

      for (var r = 0; r < rows.length; r++) {
        final cols = rows[r].split(',');
        parsed.add(cols.map((v) => int.tryParse(v) ?? 0).toList());
      }
      return parsed;
    } catch (_) {
      return emptyGrid;
    }
  }

  /// Encodes grid state to standard serialized string.
  static String encodeGrid(List<List<int>> grid) {
    return grid.map((row) => row.join(',')).join(';');
  }
}
