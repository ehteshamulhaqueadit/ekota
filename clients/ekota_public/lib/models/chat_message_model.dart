class ChatMessageModel {
  final String id;
  final String listingId;
  final String? senderId;
  final String senderName;
  final String type; // 'TEXT', 'MEDIA', 'SYSTEM'
  final String content;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final String? tempId;

  ChatMessageModel({
    required this.id,
    required this.listingId,
    this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.mediaUrl,
    this.metadata,
    required this.createdAt,
    this.tempId,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      senderId: json['senderId'],
      senderName: json['senderName'] ?? (json['sender']?['fullName'] ?? 'Participant'),
      type: (json['type'] ?? 'TEXT').toString().toUpperCase(),
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'],
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      tempId: json['tempId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'content': content,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'tempId': tempId,
    };
  }
}

class SyndicateThreadModel {
  final String id;
  final String assetName;
  final String category;
  final double fundingTarget;
  final double rentalPrice;
  final double currentFunding;
  final int fundingPercentage;
  final List<String> imageUrls;
  final String producerName;
  final String status;

  SyndicateThreadModel({
    required this.id,
    required this.assetName,
    required this.category,
    required this.fundingTarget,
    required this.rentalPrice,
    required this.currentFunding,
    required this.fundingPercentage,
    required this.imageUrls,
    required this.producerName,
    required this.status,
  });

  factory SyndicateThreadModel.fromJson(Map<String, dynamic> json) {
    return SyndicateThreadModel(
      id: json['id'] ?? '',
      assetName: json['assetName'] ?? 'Asset Listing',
      category: json['category'] ?? 'General',
      fundingTarget: (json['fundingTarget'] ?? 100000).toDouble(),
      rentalPrice: (json['rentalPrice'] ?? 1000).toDouble(),
      currentFunding: (json['currentFunding'] ?? 0).toDouble(),
      fundingPercentage: json['fundingPercentage'] ?? 0,
      imageUrls: json['imageUrls'] is List ? List<String>.from(json['imageUrls']) : [],
      producerName: json['producerName'] ?? 'Producer',
      status: json['status'] ?? 'active',
    );
  }
}
