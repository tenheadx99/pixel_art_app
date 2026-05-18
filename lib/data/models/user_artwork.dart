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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pixelArtId': pixelArtId,
      'name': name,
      'filePath': filePath,
      'dateCreated': dateCreated.toIso8601String(),
      'completionPercent': completionPercent,
    };
  }

  factory UserArtwork.fromJson(Map<String, dynamic> json) {
    return UserArtwork(
      id: json['id'] as String,
      pixelArtId: json['pixelArtId'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String,
      dateCreated: DateTime.parse(json['dateCreated'] as String),
      completionPercent: json['completionPercent'] as int? ?? 100,
    );
  }
}
