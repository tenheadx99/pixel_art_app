/// Configuration for a horizontal artwork shelf.
/// Can be loaded from Firestore (`pixel_art/{flavor}.shelves`) or RemoteConfig,
/// or fall back to default curated slices (Top 10, Seasonal, New, Quick, Categories).
class ShelfConfig {
  final String id;
  final String title;
  final String emoji;
  final String type; // 'top10', 'seasonal', 'new', 'quick', 'category', 'custom'
  final String? subtitle;
  final String? category;
  final String? tag;
  final List<String>? artworkIds;
  final bool isEnabled;
  final int sortOrder;

  const ShelfConfig({
    required this.id,
    required this.title,
    this.emoji = '🎨',
    this.type = 'category',
    this.subtitle,
    this.category,
    this.tag,
    this.artworkIds,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  factory ShelfConfig.fromJson(Map<String, dynamic> json) {
    return ShelfConfig(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Collection',
      emoji: json['emoji'] as String? ?? '🎨',
      type: json['type'] as String? ?? 'category',
      subtitle: json['subtitle'] as String?,
      category: json['category'] as String?,
      tag: json['tag'] as String?,
      artworkIds: (json['artworkIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      isEnabled: json['isEnabled'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'type': type,
    if (subtitle != null) 'subtitle': subtitle,
    if (category != null) 'category': category,
    if (tag != null) 'tag': tag,
    if (artworkIds != null) 'artworkIds': artworkIds,
    'isEnabled': isEnabled,
    'sortOrder': sortOrder,
  };
}

