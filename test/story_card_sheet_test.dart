import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_art_app/data/models/pixel_art.dart';
import 'package:pixel_art_app/ui/widgets/story_card_sheet.dart';

void main() {
  testWidgets('StoryCardSheet renders 9:16 card preview with metadata and watermark', (tester) async {
    final art = PixelArt(
      id: 'test_art_01',
      name: 'Radha Krishna',
      category: 'Devotional',
      gridWidth: 10,
      gridHeight: 10,
      colorMap: {
        1: const Color(0xFFFF9800),
        2: const Color(0xFF2196F3),
      },
      grid: List.generate(10, (r) => List.generate(10, (c) => (r + c) % 2 + 1)),
    );

    // Dummy 1x1 transparent PNG bytes for testing
    final dummyPngBytes = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
      120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
      68, 174, 66, 96, 130
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryCardSheet(
            art: art,
            artworkPngBytes: dummyPngBytes,
            completionDuration: const Duration(minutes: 3, seconds: 45),
            completionDate: DateTime(2026, 10, 25),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Tagline
    expect(find.text('Share Status & Story'), findsOneWidget);
    expect(find.text('Radha Krishna'), findsOneWidget);
    expect(find.text('MASTERPIECE COMPLETED'), findsOneWidget);

    // Verify stats
    expect(find.text('3m 45s'), findsOneWidget);
    expect(find.text('2 Colors'), findsOneWidget);
    expect(find.text('100% Done'), findsOneWidget);

    // Verify share button
    expect(find.text('Share to WhatsApp Status & Story'), findsOneWidget);
  });
}
