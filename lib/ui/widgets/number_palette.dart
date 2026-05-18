import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';
import '../theme/app_style.dart';

class NumberPalette extends StatelessWidget {
  final ColoringProvider provider;

  const NumberPalette({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final art = provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    final numbers = art.sortedNumbers;
    if (numbers.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text('Select a number',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(130))),
                const Spacer(),
                GestureDetector(
                  onTap: provider.toggleNumbers,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppStyle.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(provider.showNumbers ? Icons.visibility : Icons.visibility_off,
                            size: 12, color: AppStyle.primary),
                        const SizedBox(width: 4),
                        Text(provider.showNumbers ? 'Show' : 'Hide',
                            style: const TextStyle(fontSize: 10, color: AppStyle.primary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: numbers.map((number) {
                final color = art.colorForNumber(number) ?? AppStyle.numberToColor(number);
                final isSelected = provider.selectedNumber == number;
                final fillPercent = _getFillPercent(number);

                return GestureDetector(
                  onTap: () => provider.selectNumber(number),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.black.withAlpha(25),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withAlpha(120), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 3))]
                          : [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$number', style: TextStyle(color: _textColorForBg(color), fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        if (fillPercent > 0)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Container(
                              width: 20, height: 3,
                              color: Colors.black.withAlpha(40),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: fillPercent.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _textColorForBg(color).withAlpha(150),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Text('${_getCellCount(number)}',
                              style: TextStyle(fontSize: 9, color: _textColorForBg(color).withAlpha(100))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int _getCellCount(int number) {
    final art = provider.currentArt;
    if (art == null) return 0;
    int count = 0;
    for (var row = 0; row < art.gridHeight; row++) {
      for (var col = 0; col < art.gridWidth; col++) {
        if (art.grid[row][col] == number) count++;
      }
    }
    return count;
  }

  double _getFillPercent(int number) {
    final art = provider.currentArt;
    if (art == null) return 0;
    int total = 0;
    int filled = 0;
    for (var row = 0; row < art.gridHeight; row++) {
      for (var col = 0; col < art.gridWidth; col++) {
        if (art.grid[row][col] == number) {
          total++;
          if (provider.filledGrid[row][col] == number) filled++;
        }
      }
    }
    if (total == 0) return 0;
    return filled / total;
  }

  Color _textColorForBg(Color bg) {
    final luminance = (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b);
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
