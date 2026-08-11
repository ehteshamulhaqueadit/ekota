import 'dart:convert';
import 'api_client.dart';

class VotingService {
  /// Create a rent price proposal
  static Future<Map<String, dynamic>> createProposal({
    required String poolItemId,
    required double proposedPrice,
    String? reason,
  }) async {
    final response = await ApiClient.post('rental-pool/$poolItemId/proposals', body: {
      'proposedPrice': proposedPrice,
      if (reason != null) 'reason': reason,
    });
    return jsonDecode(response.body);
  }

  /// Get all proposals for a rental pool item
  static Future<List<Map<String, dynamic>>> getProposals(String poolItemId) async {
    final response = await ApiClient.get('rental-pool/$poolItemId/proposals');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  /// Cast a vote on a proposal
  static Future<Map<String, dynamic>> castVote({
    required String proposalId,
    required String voteType,
  }) async {
    final response = await ApiClient.post('proposals/$proposalId/vote', body: {
      'voteType': voteType,
    });
    return jsonDecode(response.body);
  }

  /// Get voting results for a proposal
  static Future<Map<String, dynamic>> getVotingResults(String proposalId) async {
    final response = await ApiClient.get('proposals/$proposalId/results');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }
}
