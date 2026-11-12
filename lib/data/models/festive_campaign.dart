/// Configuration for a dynamic festive or seasonal campaign dialog popup.
/// Loaded from Firestore root doc `pixel_art/{flavor}` (`festiveCampaign`).
class FestiveCampaign {
  final bool isEnabled;
  final String campaignId;
  final String title;
  final String emoji;
  final String message;
  final String themeGradient; // 'gold', 'crimson', 'purple', 'spring', 'cyber', 'sunset'
  final int rewardDiamonds;
  final String buttonLabel;
  final String targetType; // 'none', 'category', 'shelf', 'artwork'
  final String? targetId;
  final DateTime? startDate;
  final DateTime? endDate;

  const FestiveCampaign({
    this.isEnabled = false,
    this.campaignId = '',
    this.title = '',
    this.emoji = '🎉',
    this.message = '',
    this.themeGradient = 'gold',
    this.rewardDiamonds = 0,
    this.buttonLabel = 'Awesome!',
    this.targetType = 'none',
    this.targetId,
    this.startDate,
    this.endDate,
  });

  factory FestiveCampaign.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final cid = (json['campaignId'] as String?)?.trim();
    return FestiveCampaign(
      isEnabled: json['isEnabled'] as bool? ?? false,
      campaignId: (cid != null && cid.isNotEmpty) ? cid : 'campaign_default',
      title: json['title'] as String? ?? 'Special Festive Celebration!',
      emoji: json['emoji'] as String? ?? '🎉',
      message: json['message'] as String? ?? '',
      themeGradient: json['themeGradient'] as String? ?? 'gold',
      rewardDiamonds: (json['rewardDiamonds'] as num?)?.toInt() ?? 0,
      buttonLabel: json['buttonLabel'] as String? ?? 'Awesome!',
      targetType: json['targetType'] as String? ?? 'none',
      targetId: json['targetId'] as String?,
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
    );
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'campaignId': campaignId,
        'title': title,
        'emoji': emoji,
        'message': message,
        'themeGradient': themeGradient,
        'rewardDiamonds': rewardDiamonds,
        'buttonLabel': buttonLabel,
        'targetType': targetType,
        if (targetId != null) 'targetId': targetId,
        if (startDate != null) 'startDate': startDate!.millisecondsSinceEpoch,
        if (endDate != null) 'endDate': endDate!.millisecondsSinceEpoch,
      };

  bool get isActiveNow {
    if (!isEnabled) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}

