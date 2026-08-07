import '../models/listing.dart';
import '../models/comment.dart';
import '../models/review.dart';
import 'api_client.dart';

class ListingService {
  final ApiClient _api = ApiClient();

  // ── Listings ──────────────────────────────────────────────────────────────

  Future<List<Listing>> getMyListings(String producerId) async {
    final data = await _api.get('/producers/$producerId/listings');
    return (data as List)
        .map((j) => Listing.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Listing> getListing(String id) async {
    final data = await _api.get('/listings/$id');
    return Listing.fromJson(data as Map<String, dynamic>);
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    final data = await _api.post('/listings', payload);
    return Listing.fromJson(data as Map<String, dynamic>);
  }

  // ── Votes ─────────────────────────────────────────────────────────────────

  Future<void> vote(String listingId, String type) =>
      _api.post('/listings/$listingId/vote', {'type': type});

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<List<Comment>> getComments(String listingId) async {
    final data = await _api.get('/listings/$listingId/comments');
    return (data as List)
        .map((j) => Comment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Comment> postComment(String listingId, String text) async {
    final data =
        await _api.post('/listings/$listingId/comments', {'text': text});
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  Future<Comment> postReply(String commentId, String text) async {
    final data =
        await _api.post('/comments/$commentId/reply', {'text': text});
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  Future<List<Review>> getReviews(String listingId) async {
    final data = await _api.get('/listings/$listingId/reviews');
    return (data as List)
        .map((j) => Review.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<bool> canReview(String listingId) async {
    final data = await _api.get('/listings/$listingId/can-review');
    return (data as Map<String, dynamic>)['canReview'] == true;
  }

  Future<Review> postReview(String listingId, String text) async {
    final data =
        await _api.post('/listings/$listingId/reviews', {'text': text});
    return Review.fromJson(data as Map<String, dynamic>);
  }
}
