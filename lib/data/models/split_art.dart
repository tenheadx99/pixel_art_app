import 'pixel_art.dart';

/// Pure helpers for split artworks: a large parent grid is sliced into
/// uniform tiles ("parts"), each colored as its own virtual [PixelArt].
/// Part ids are `<parentId>_p<index>` (row-major, 0-based); no bundled or
/// remote catalog id uses that suffix (remote ids are `rmt_<slug>_<millis>`).
class SplitArt {
  SplitArt._();

  static final RegExp _partSuffix = RegExp(r'^(.+)_p(\d+)$');

  /// Upper bound on tiles, guarding against malformed remote docs.
  static const int maxParts = 25;

  static String partId(String parentId, int index) => '${parentId}_p$index';

  static bool isPartId(String id) => _partSuffix.hasMatch(id);

  static String? parentIdOf(String id) => _partSuffix.firstMatch(id)?.group(1);

  static int? partIndexOf(String id) {
    final m = _partSuffix.firstMatch(id);
    return m == null ? null : int.parse(m.group(2)!);
  }

  /// Whether [art]'s split metadata is usable: tiles divide the grid evenly
  /// and the tile count is sane. Non-split art is trivially valid.
  static bool validSplit(PixelArt art) {
    if (!art.isSplit) return true;
    if (art.partsX < 1 || art.partsY < 1) return false;
    if (art.partCount > maxParts) return false;
    return art.gridWidth % art.partsX == 0 && art.gridHeight % art.partsY == 0;
  }

  /// Slice part [index] (row-major) out of [parent] as a standalone artwork.
  /// The full parent palette is reused — sparse color numbering is legal and
  /// the palette UI only shows the part's own used numbers.
  static PixelArt partOf(PixelArt parent, int index) {
    assert(parent.isSplit && validSplit(parent));
    assert(index >= 0 && index < parent.partCount);
    final pw = parent.partWidth;
    final ph = parent.partHeight;
    final row0 = (index ~/ parent.partsX) * ph;
    final col0 = (index % parent.partsX) * pw;
    final grid = [
      for (int r = row0; r < row0 + ph; r++)
        parent.grid[r].sublist(col0, col0 + pw),
    ];
    return PixelArt(
      id: partId(parent.id, index),
      name: '${parent.name} · Part ${index + 1}/${parent.partCount}',
      gridWidth: pw,
      gridHeight: ph,
      grid: grid,
      colorMap: parent.colorMap,
      category: parent.category,
      difficulty: parent.difficulty,
      isPremium: parent.isPremium,
      availableFrom: parent.availableFrom,
      availableUntil: parent.availableUntil,
    );
  }

  /// Fillable (non-background) cell count of every part, row-major. One full
  /// grid scan — callers should memoize per parent id.
  static List<int> partFillableCounts(PixelArt parent) {
    final counts = List<int>.filled(parent.partCount, 0);
    final pw = parent.partWidth;
    final ph = parent.partHeight;
    for (int r = 0; r < parent.gridHeight; r++) {
      final row = parent.grid[r];
      final partRow = (r ~/ ph) * parent.partsX;
      for (int c = 0; c < parent.gridWidth; c++) {
        if (row[c] > 0) counts[partRow + c ~/ pw]++;
      }
    }
    return counts;
  }
}
