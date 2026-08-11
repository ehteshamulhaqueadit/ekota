const prisma = require('../config/prisma');

// POST /api/rental-pool/:poolItemId/proposals - Create a rent price change proposal
async function createProposal(req, res) {
  const userId = req.user.id;
  const { poolItemId } = req.params;
  const { proposedPrice, reason } = req.body;

  if (!proposedPrice || proposedPrice <= 0) {
    return res.status(400).json({ error: 'A positive proposedPrice is required' });
  }

  try {
    // Get the pool item and listing
    const poolItem = await prisma.rentalPoolItem.findUnique({
      where: { id: poolItemId },
      include: { listing: true }
    });

    if (!poolItem) return res.status(404).json({ error: 'Rental pool item not found' });

    // Verify the user is an investor
    const investment = await prisma.investment.findUnique({
      where: { userId_listingId: { userId, listingId: poolItem.listingId } }
    });

    if (!investment) {
      return res.status(403).json({ error: 'Only investors in this product can create proposals' });
    }

    // Check for existing active proposals
    const activeProposal = await prisma.rentPriceProposal.findFirst({
      where: {
        listingId: poolItem.listingId,
        status: 'ACTIVE'
      }
    });

    if (activeProposal) {
      return res.status(409).json({ error: 'There is already an active proposal for this product. Vote on it or wait for it to expire.' });
    }

    // Create proposal with 7-day expiry
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const proposal = await prisma.rentPriceProposal.create({
      data: {
        listingId: poolItem.listingId,
        proposedPrice,
        reason: reason || null,
        proposedById: userId,
        expiresAt,
        status: 'ACTIVE'
      }
    });

    res.status(201).json({
      proposal,
      currentRentPrice: poolItem.currentRentPrice,
      message: 'Rent price change proposal created. Investors can now vote.'
    });
  } catch (error) {
    console.error('Error creating proposal:', error);
    res.status(500).json({ error: 'Failed to create proposal' });
  }
}

// GET /api/rental-pool/:poolItemId/proposals - List all proposals for a rental pool item
async function getProposals(req, res) {
  const { poolItemId } = req.params;

  try {
    const poolItem = await prisma.rentalPoolItem.findUnique({
      where: { id: poolItemId }
    });

    if (!poolItem) return res.status(404).json({ error: 'Rental pool item not found' });

    const proposals = await prisma.rentPriceProposal.findMany({
      where: { listingId: poolItem.listingId },
      include: {
        votes: {
          include: {
            voter: { select: { id: true, fullName: true } }
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = proposals.map(p => {
      const totalWeight = p.votes.reduce((sum, v) => sum + v.weight, 0);
      const increaseWeight = p.votes
        .filter(v => v.voteType === 'INCREASE')
        .reduce((sum, v) => sum + v.weight, 0);
      const decreaseWeight = p.votes
        .filter(v => v.voteType === 'DECREASE')
        .reduce((sum, v) => sum + v.weight, 0);
      const holdWeight = p.votes
        .filter(v => v.voteType === 'HOLD')
        .reduce((sum, v) => sum + v.weight, 0);

      return {
        id: p.id,
        proposedPrice: p.proposedPrice,
        reason: p.reason,
        status: p.status,
        expiresAt: p.expiresAt,
        createdAt: p.createdAt,
        currentRentPrice: poolItem.currentRentPrice,
        voteSummary: {
          totalVoteWeight: totalWeight,
          increaseWeight,
          decreaseWeight,
          holdWeight,
          voterCount: p.votes.length
        },
        votes: p.votes.map(v => ({
          voterId: v.voterId,
          voterName: v.voter.fullName,
          voteType: v.voteType,
          weight: v.weight
        }))
      };
    });

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching proposals:', error);
    res.status(500).json({ error: 'Failed to fetch proposals' });
  }
}

// POST /api/proposals/:proposalId/vote - Cast a weighted vote
async function castVote(req, res) {
  const userId = req.user.id;
  const { proposalId } = req.params;
  const { voteType } = req.body;

  if (!['INCREASE', 'DECREASE', 'HOLD'].includes(voteType)) {
    return res.status(400).json({ error: 'voteType must be INCREASE, DECREASE, or HOLD' });
  }

  try {
    const proposal = await prisma.rentPriceProposal.findUnique({
      where: { id: proposalId }
    });

    if (!proposal) return res.status(404).json({ error: 'Proposal not found' });
    if (proposal.status !== 'ACTIVE') {
      return res.status(400).json({ error: 'This proposal is no longer active' });
    }
    if (new Date() > proposal.expiresAt) {
      // Auto-expire
      await prisma.rentPriceProposal.update({
        where: { id: proposalId },
        data: { status: 'EXPIRED' }
      });
      return res.status(400).json({ error: 'This proposal has expired' });
    }

    // Get investor's share
    const investment = await prisma.investment.findUnique({
      where: { userId_listingId: { userId, listingId: proposal.listingId } }
    });

    if (!investment) {
      return res.status(403).json({ error: 'Only investors in this product can vote' });
    }

    // Check if already voted
    const existingVote = await prisma.rentPriceVote.findUnique({
      where: { proposalId_voterId: { proposalId, voterId: userId } }
    });

    if (existingVote) {
      return res.status(409).json({ error: 'You have already voted on this proposal' });
    }

    const vote = await prisma.rentPriceVote.create({
      data: {
        proposalId,
        voterId: userId,
        voteType,
        weight: investment.sharePercentage
      }
    });

    // Check if the vote changes the outcome (auto-resolve if >50% weight voted same way)
    const allVotes = await prisma.rentPriceVote.findMany({
      where: { proposalId }
    });

    const increaseWeight = allVotes
      .filter(v => v.voteType === 'INCREASE')
      .reduce((sum, v) => sum + v.weight, 0);
    const decreaseWeight = allVotes
      .filter(v => v.voteType === 'DECREASE')
      .reduce((sum, v) => sum + v.weight, 0);

    let proposalResolved = false;
    let newStatus = 'ACTIVE';

    // The proposal type is determined by whether proposedPrice > currentRentPrice
    // If >50% weight votes INCREASE (for price increase proposals) or DECREASE (for decrease proposals), it passes
    if (increaseWeight > 50) {
      // Majority wants increase — pass the proposal
      newStatus = 'PASSED';
      proposalResolved = true;
    } else if (decreaseWeight > 50) {
      // Majority wants decrease — pass the proposal  
      newStatus = 'PASSED';
      proposalResolved = true;
    }

    if (proposalResolved) {
      await prisma.$transaction(async (tx) => {
        await tx.rentPriceProposal.update({
          where: { id: proposalId },
          data: { status: newStatus }
        });

        if (newStatus === 'PASSED') {
          // Update the rental pool item price
          await tx.rentalPoolItem.update({
            where: { listingId: proposal.listingId },
            data: { currentRentPrice: proposal.proposedPrice }
          });
        }
      });
    }

    res.status(201).json({
      vote,
      proposalStatus: newStatus,
      proposalResolved,
      message: proposalResolved
        ? `Proposal ${newStatus.toLowerCase()}. Rent price updated to ${proposal.proposedPrice}.`
        : 'Vote cast successfully.'
    });
  } catch (error) {
    console.error('Error casting vote:', error);
    res.status(500).json({ error: 'Failed to cast vote' });
  }
}

// GET /api/proposals/:proposalId/results - Get voting results
async function getVotingResults(req, res) {
  const { proposalId } = req.params;

  try {
    const proposal = await prisma.rentPriceProposal.findUnique({
      where: { id: proposalId },
      include: {
        votes: {
          include: {
            voter: { select: { id: true, fullName: true } }
          }
        },
        listing: {
          select: { assetName: true, rentalPrice: true },
          include: {
            rentalPoolItem: { select: { currentRentPrice: true } }
          }
        }
      }
    });

    if (!proposal) return res.status(404).json({ error: 'Proposal not found' });

    const increaseWeight = proposal.votes
      .filter(v => v.voteType === 'INCREASE')
      .reduce((sum, v) => sum + v.weight, 0);
    const decreaseWeight = proposal.votes
      .filter(v => v.voteType === 'DECREASE')
      .reduce((sum, v) => sum + v.weight, 0);
    const holdWeight = proposal.votes
      .filter(v => v.voteType === 'HOLD')
      .reduce((sum, v) => sum + v.weight, 0);

    res.json({
      proposalId: proposal.id,
      proposedPrice: proposal.proposedPrice,
      reason: proposal.reason,
      status: proposal.status,
      expiresAt: proposal.expiresAt,
      assetName: proposal.listing.assetName,
      currentRentPrice: proposal.listing.rentalPoolItem?.currentRentPrice || proposal.listing.rentalPrice,
      results: {
        increaseWeight,
        decreaseWeight,
        holdWeight,
        totalWeight: increaseWeight + decreaseWeight + holdWeight,
        voterCount: proposal.votes.length
      },
      votes: proposal.votes.map(v => ({
        voterName: v.voter.fullName,
        voteType: v.voteType,
        weight: v.weight
      }))
    });
  } catch (error) {
    console.error('Error fetching voting results:', error);
    res.status(500).json({ error: 'Failed to fetch voting results' });
  }
}

module.exports = {
  createProposal,
  getProposals,
  castVote,
  getVotingResults
};
