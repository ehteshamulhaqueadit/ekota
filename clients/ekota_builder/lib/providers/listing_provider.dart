import 'package:flutter/foundation.dart';
import '../models/listing.dart';
import '../models/comment.dart';
import '../models/review.dart';
import '../services/listing_service.dart';

class ListingProvider extends ChangeNotifier {
  final _service = ListingService();

  Listing? listing;
  List<Comment> comments = [];
  List<Review> reviews = [];
  bool canReview = false;
  bool loading = false;
  String? error;

  // ── Load full listing detail ───────────────────────────────────────────────

  Future<void> loadListing(String id) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getListing(id),
        _service.getComments(id),
        _service.getReviews(id),
        _service.canReview(id),
      ]);
      listing = results[0] as Listing;
      comments = results[1] as List<Comment>;
      reviews = results[2] as List<Review>;
      canReview = results[3] as bool;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── Voting (optimistic) ───────────────────────────────────────────────────

  Future<void> vote(VoteType type) async {
    if (listing == null) return;
    final prev = listing!.myVote;
    listing = _applyVoteLocally(listing!, type);
    notifyListeners();
    try {
      final typeStr = type == VoteType.up
          ? 'up'
          : type == VoteType.down
              ? 'down'
              : 'none';
      await _service.vote(listing!.id, typeStr);
    } catch (_) {
      listing = _applyVoteLocally(listing!, prev); // roll back
      notifyListeners();
    }
  }

  Listing _applyVoteLocally(Listing l, VoteType newVote) {
    int up = l.upvotes, down = l.downvotes;
    if (l.myVote == VoteType.up) up--;
    if (l.myVote == VoteType.down) down--;
    if (newVote == VoteType.up) up++;
    if (newVote == VoteType.down) down++;
    return l.copyWith(upvotes: up, downvotes: down, myVote: newVote);
  }

  // ── Comments ─────────────────────────────────────────────────────────────

  Future<void> addComment(String text) async {
    if (listing == null) return;
    final c = await _service.postComment(listing!.id, text);
    comments = [c, ...comments];
    notifyListeners();
  }

  Future<void> addReply(String commentId, String text) async {
    final replied = await _service.postReply(commentId, text);
    comments =
        comments.map((c) => c.id == commentId ? replied : c).toList();
    notifyListeners();
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<void> addReview(String text) async {
    if (listing == null) return;
    final r = await _service.postReview(listing!.id, text);
    reviews = [r, ...reviews];
    notifyListeners();
  }

  void reset() {
    listing = null;
    comments = [];
    reviews = [];
    canReview = false;
    loading = false;
    error = null;
  }
}
