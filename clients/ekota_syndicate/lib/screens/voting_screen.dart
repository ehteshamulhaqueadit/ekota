import 'package:flutter/material.dart';
import '../services/voting_service.dart';

class VotingScreen extends StatefulWidget {
  final String poolItemId;
  final String listingId;
  final double currentRentPrice;

  const VotingScreen({
    super.key,
    required this.poolItemId,
    required this.listingId,
    required this.currentRentPrice,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  List<Map<String, dynamic>> _proposals = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  final _priceController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProposals();
  }

  Future<void> _loadProposals() async {
    setState(() => _isLoading = true);
    try {
      final proposals = await VotingService.getProposals(widget.poolItemId);
      if (!mounted) return;
      setState(() { _proposals = proposals; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createProposal() async {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await VotingService.createProposal(
        poolItemId: widget.poolItemId,
        proposedPrice: price,
        reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Done')),
      );
      _priceController.clear();
      _reasonController.clear();
      _loadProposals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _castVote(String proposalId, String voteType) async {
    try {
      final result = await VotingService.castVote(proposalId: proposalId, voteType: voteType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? result['error'] ?? 'Vote cast')),
      );
      _loadProposals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Price Voting'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProposals,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current price
                    Card(
                      color: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.attach_money, color: Color(0xFF00D2FF), size: 28),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                const Text('Current Rent Price', style: TextStyle(color: Colors.white60)),
                                Text('৳${widget.currentRentPrice.toStringAsFixed(0)} / day',
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Create proposal
                    const Text('Create New Proposal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Proposed Price (৳/day)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.price_change),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _createProposal,
                        icon: const Icon(Icons.add_circle_outline),
                        label: _isSubmitting
                            ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            : const Text('Submit Proposal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    // Proposals list
                    const Text('Active Proposals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (_proposals.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No proposals yet', style: TextStyle(color: Colors.grey)),
                      ))
                    else
                      ..._proposals.map((proposal) => _buildProposalCard(proposal)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    final status = proposal['status'] ?? '';
    final isActive = status == 'ACTIVE';
    final voteSummary = proposal['voteSummary'] ?? {};
    final increaseWeight = (voteSummary['increaseWeight'] ?? 0).toDouble();
    final decreaseWeight = (voteSummary['decreaseWeight'] ?? 0).toDouble();
    final holdWeight = (voteSummary['holdWeight'] ?? 0).toDouble();
    final totalWeight = increaseWeight + decreaseWeight + holdWeight;

    Color statusColor;
    switch (status) {
      case 'PASSED': statusColor = Colors.green; break;
      case 'REJECTED': statusColor = Colors.red; break;
      case 'EXPIRED': statusColor = Colors.grey; break;
      default: statusColor = Colors.orange; break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Proposed: ৳${(proposal['proposedPrice'] ?? 0).toStringAsFixed(0)}/day',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            if (proposal['reason'] != null && proposal['reason'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Reason: ${proposal['reason']}', style: TextStyle(color: Colors.grey[600])),
            ],
            const SizedBox(height: 16),

            // Vote summary
            const Text('Vote Distribution (Weighted)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _voteBar('Increase', increaseWeight, totalWeight, Colors.green),
            _voteBar('Decrease', decreaseWeight, totalWeight, Colors.red),
            _voteBar('Hold', holdWeight, totalWeight, Colors.orange),
            const SizedBox(height: 8),
            Text('${voteSummary['voterCount'] ?? 0} voters · ${totalWeight.toStringAsFixed(1)}% weight cast',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),

            // Vote buttons
            if (isActive) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _voteButton('INCREASE', Colors.green, Icons.arrow_upward, proposal['id'])),
                  const SizedBox(width: 8),
                  Expanded(child: _voteButton('HOLD', Colors.orange, Icons.pause, proposal['id'])),
                  const SizedBox(width: 8),
                  Expanded(child: _voteButton('DECREASE', Colors.red, Icons.arrow_downward, proposal['id'])),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _voteBar(String label, double weight, double total, Color color) {
    final pct = total > 0 ? weight / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey[200],
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 45, child: Text('${weight.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _voteButton(String voteType, Color color, IconData icon, String proposalId) {
    return ElevatedButton.icon(
      onPressed: () => _castVote(proposalId, voteType),
      icon: Icon(icon, size: 16),
      label: Text(voteType.substring(0, 1) + voteType.substring(1).toLowerCase(), style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
