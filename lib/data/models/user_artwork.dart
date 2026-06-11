class UserArtwork {
  final String id;
  final String pixelArtId;
  final String name;
  final String filePath;
  final DateTime dateCreated;
  final int completionPercent;

  const UserArtwork({
    required this.id,
    required this.pixelArtId,
    required this.name,
    required this.filePath,
    required this.dateCreated,
    this.completionPercent = 100,
  });

  /// Keys match the `saved_artworks` table columns in DatabaseService.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pixel_art_id': pixelArtId,
      'name': name,
      'file_path': filePath,
      'date_created': dateCreated.toIso8601String(),
      'completion_percent': completionPercent,
    };
  }

  factory UserArtwork.fromJson(Map<String, dynamic> json) {
    return UserArtwork(
      id: json['id'] as String,
      pixelArtId: json['pixel_art_id'] as String,
      name: json['name'] as String,
      filePath: json['file_path'] as String? ?? '',
      dateCreated:
          DateTime.tryParse(json['date_created'] as String? ?? '') ??
          DateTime.now(),
      completionPercent: json['completion_percent'] as int? ?? 100,
    );
  }
}
