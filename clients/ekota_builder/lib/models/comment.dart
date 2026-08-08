class Comment {
  final String id;
  final String listingId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final Comment? reply; // producer's single reply, if any

  const Comment({
    required this.id,
    required this.listingId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.reply,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        listingId: j['listingId'] as String,
        authorId: j['authorId'] as String,
        authorName: j['authorName'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        reply: j['reply'] != null
            ? Comment.fromJson(j['reply'] as Map<String, dynamic>)
            : null,
      );
}
