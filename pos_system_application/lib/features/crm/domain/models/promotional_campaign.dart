class PromotionalCampaignModel {
  final String id;
  final String businessId;
  final String title;
  final String targetSegment;
  final String? targetGroupId;
  final String channel;
  final String messageTemplate;
  final String? promotionId;
  final int audienceCount;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime createdAt;

  const PromotionalCampaignModel({
    required this.id,
    required this.businessId,
    required this.title,
    required this.targetSegment,
    this.targetGroupId,
    required this.channel,
    required this.messageTemplate,
    this.promotionId,
    required this.audienceCount,
    required this.status,
    this.scheduledAt,
    this.sentAt,
    required this.createdAt,
  });

  factory PromotionalCampaignModel.fromJson(Map<String, dynamic> json) {
    return PromotionalCampaignModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      title: json['title'] as String,
      targetSegment: json['target_segment'] as String? ?? 'ALL',
      targetGroupId: json['target_group_id'] as String?,
      channel: json['channel'] as String? ?? 'SMS',
      messageTemplate: json['message_template'] as String? ?? '',
      promotionId: json['promotion_id'] as String?,
      audienceCount: (json['audience_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'DRAFT',
      scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at'] as String) : null,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'target_segment': targetSegment,
      'target_group_id': targetGroupId,
      'channel': channel,
      'message_template': messageTemplate,
      'promotion_id': promotionId,
      'scheduled_at': scheduledAt?.toIso8601String(),
    };
  }
}

