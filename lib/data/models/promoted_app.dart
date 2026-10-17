class PromotedApp {
  final String id;
  final String title;
  final String tagline;
  final String packageName;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String iconUrl;
  final String? bannerUrl;
  final double rating;
  final String downloadCount;
  final String? badge; // 'HOT', 'NEW', 'FEATURED'
  final int sortOrder;
  final bool enabled;
  final List<String> targetFlavors;

  const PromotedApp({
    required this.id,
    required this.title,
    required this.tagline,
    required this.packageName,
    this.playStoreUrl,
    this.appStoreUrl,
    required this.iconUrl,
    this.bannerUrl,
    this.rating = 4.8,
    this.downloadCount = '100K+',
    this.badge,
    this.sortOrder = 0,
    this.enabled = true,
    this.targetFlavors = const ['all'],
  });

  factory PromotedApp.fromJson(Map<String, dynamic> json) {
    double parsedRating = 4.8;
    final r = json['rating'];
    if (r is num) {
      parsedRating = r.toDouble();
    } else if (r is String) {
      parsedRating = double.tryParse(r) ?? 4.8;
    }

    int parsedSortOrder = 0;
    final so = json['sortOrder'];
    if (so is num) {
      parsedSortOrder = so.toInt();
    } else if (so is String) {
      parsedSortOrder = int.tryParse(so) ?? 0;
    }

    bool parsedEnabled = true;
    final en = json['enabled'];
    if (en is bool) {
      parsedEnabled = en;
    } else if (en is String) {
      parsedEnabled = en.toLowerCase() != 'false';
    }

    List<String> parsedTargets = const ['all'];
    final tf = json['targetFlavors'];
    if (tf is List) {
      parsedTargets = tf.map((e) => e.toString()).toList();
    } else if (tf is String) {
      parsedTargets = [tf];
    }

    return PromotedApp(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String?,
      appStoreUrl: json['appStoreUrl'] as String?,
      iconUrl: json['iconUrl'] as String? ?? '',
      bannerUrl: json['bannerUrl'] as String?,
      rating: parsedRating,
      downloadCount: json['downloadCount'] as String? ?? '50K+',
      badge: json['badge'] as String?,
      sortOrder: parsedSortOrder,
      enabled: parsedEnabled,
      targetFlavors: parsedTargets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'tagline': tagline,
      'packageName': packageName,
      if (playStoreUrl != null) 'playStoreUrl': playStoreUrl,
      if (appStoreUrl != null) 'appStoreUrl': appStoreUrl,
      'iconUrl': iconUrl,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
      'rating': rating,
      'downloadCount': downloadCount,
      if (badge != null) 'badge': badge,
      'sortOrder': sortOrder,
      'enabled': enabled,
      'targetFlavors': targetFlavors,
    };
  }

  /// Direct Google Play URL for Android devices.
  String get effectivePlayStoreUrl =>
      playStoreUrl?.isNotEmpty == true
          ? playStoreUrl!
          : 'https://play.google.com/store/apps/details?id=$packageName';
}
