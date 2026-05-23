import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';
import '../theme/app_style.dart';

class NumberPalette extends StatelessWidget {
  final ColoringProvider provider;

  const NumberPalette({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final art = provider.currentArt;
    if (art == null) return const SizedBox.shrink();

    final numbers = art.sortedNumbers;
    if (numbers.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: [
              Text(
                'Select a Color',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: provider.toggleNumbers,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppStyle.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        provider.showNumbers
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 14,
                        color: AppStyle.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.showNumbers ? 'Show Nums' : 'Hide Nums',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppStyle.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: numbers.length,
            itemBuilder: (context, index) {
              final number = numbers[index];
              final color =
                  art.colorForNumber(number) ?? AppStyle.numberToColor(number);
              final isSelected = provider.selectedNumber == number;
              final fillPercent = _getFillPercent(number);
              final isCompleted = fillPercent >= 1.0;

              return GestureDetector(
                onTap: () => provider.selectNumber(number),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 8 : 6,
                    right: index == numbers.length - 1 ? 8 : 6,
                    bottom: isSelected ? 8 : 4,
                    top: isSelected ? 2 : 6,
                  ),
                  width: isSelected ? 56 : 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : AppStyle.primary)
                          : Colors.white.withAlpha(200),
                      width: isSelected ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? color.withAlpha(160)
                            : Colors.black.withAlpha(20),
                        blurRadius: isSelected ? 12 : 6,
                        spreadRadius: isSelected ? 1 : 0,
                        offset: Offset(0, isSelected ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isCompleted)
                        Icon(
                          Icons.check_rounded,
                          color: _textColorForBg(color),
                          size: isSelected ? 28 : 24,
                        )
                      else ...[
                        Text(
                          '$number',
                          style: TextStyle(
                            color: _textColorForBg(color),
                            fontSize: isSelected ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (fillPercent > 0.0)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(80),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(fillPercent * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
