class HomeStats {
  final int gigsCompleted;
  final int gigsCurrentlyListed;
  final int investors;
  final double rating;

  const HomeStats({
    required this.gigsCompleted,
    required this.gigsCurrentlyListed,
    required this.investors,
    required this.rating,
  });

  factory HomeStats.fromJson(Map<String, dynamic> j) => HomeStats(
        gigsCompleted: j['gigsCompleted'] as int? ?? 0,
        gigsCurrentlyListed: j['gigsCurrentlyListed'] as int? ?? 0,
        investors: j['investors'] as int? ?? 0,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
      );
}
