class Review {
  final String id;
  final String listingId;
  final String investorId;
  final String investorName;
  final String text;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.listingId,
    required this.investorId,
    required this.investorName,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as String,
        listingId: j['listingId'] as String,
        investorId: j['investorId'] as String,
        investorName: j['investorName'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
