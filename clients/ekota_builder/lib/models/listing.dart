enum ProductionTimeType { instant, scheduled }

enum VoteType { none, up, down }

VoteType _voteFromString(String? s) {
  switch (s) {
    case 'up':
      return VoteType.up;
    case 'down':
      return VoteType.down;
    default:
      return VoteType.none;
  }
}

class Listing {
  final String id;
  final String producerId;
  final String assetName;
  final String category;
  final double fundingTarget;
  final double rentalPrice;
  final String description;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final ProductionTimeType productionTimeType;
  final int? productionDays;
  final String status;
  final String campaignStatus;
  final double fundingProgressPercent;
  final int investorCount;
  final String specifications;
  final int upvotes;
  final int downvotes;
  final VoteType myVote;
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.producerId,
    required this.assetName,
    required this.category,
    required this.fundingTarget,
    required this.rentalPrice,
    required this.description,
    required this.imageUrls,
    required this.videoUrls,
    required this.productionTimeType,
    this.productionDays,
    required this.status,
    required this.campaignStatus,
    required this.fundingProgressPercent,
    required this.investorCount,
    required this.specifications,
    required this.upvotes,
    required this.downvotes,
    this.myVote = VoteType.none,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
        producerId: j['producerId'] as String,
        assetName: j['assetName'] as String,
        category: j['category'] as String,
        fundingTarget: (j['fundingTarget'] as num).toDouble(),
        rentalPrice: (j['rentalPrice'] as num).toDouble(),
        description: j['description'] as String? ?? '',
        imageUrls: List<String>.from(j['imageUrls'] as List? ?? []),
        videoUrls: List<String>.from(j['videoUrls'] as List? ?? []),
        productionTimeType: j['productionTimeType'] == 'instant'
            ? ProductionTimeType.instant
            : ProductionTimeType.scheduled,
        productionDays: j['productionDays'] as int?,
        status: j['status'] as String? ?? '',
        campaignStatus: j['campaignStatus'] as String? ?? '',
        fundingProgressPercent:
            (j['fundingProgressPercent'] as num?)?.toDouble() ?? 0,
        investorCount: j['investorCount'] as int? ?? 0,
        specifications: j['specifications'] as String? ?? '',
        upvotes: j['upvotes'] as int? ?? 0,
        downvotes: j['downvotes'] as int? ?? 0,
        myVote: _voteFromString(j['myVote'] as String?),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        'assetName': assetName,
        'category': category,
        'fundingTarget': fundingTarget,
        'rentalPrice': rentalPrice,
        'description': description,
        'imageUrls': imageUrls,
        'videoUrls': videoUrls,
        'productionTimeType':
            productionTimeType == ProductionTimeType.instant
                ? 'instant'
                : 'scheduled',
        'productionDays': productionDays,
      };

  /// Creates a copy of this listing with the given fields replaced.
  Listing copyWith({
    int? upvotes,
    int? downvotes,
    VoteType? myVote,
  }) {
    return Listing(
      id: id,
      producerId: producerId,
      assetName: assetName,
      category: category,
      fundingTarget: fundingTarget,
      rentalPrice: rentalPrice,
      description: description,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
      productionTimeType: productionTimeType,
      productionDays: productionDays,
      status: status,
      campaignStatus: campaignStatus,
      fundingProgressPercent: fundingProgressPercent,
      investorCount: investorCount,
      specifications: specifications,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      myVote: myVote ?? this.myVote,
      createdAt: createdAt,
    );
  }
}
