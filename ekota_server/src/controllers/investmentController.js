const prisma = require('../config/prisma');
const { deductWalletForInvestment } = require('../services/walletService');

// POST /api/investments - Invest in a product
async function createInvestment(req, res) {
  const userId = req.user.id;
  const { listingId, amount } = req.body;

  if (!listingId || !amount || amount <= 0) {
    return res.status(400).json({ error: 'listingId and a positive amount are required' });
  }

  try {
    const listing = await prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    const remainingFunding = listing.fundingTarget - listing.currentFunded;
    if (remainingFunding <= 0) {
      return res.status(400).json({ error: 'This product is already fully funded' });
    }

    if (amount > remainingFunding) {
      return res.status(400).json({
        error: `Cannot invest more than the remaining funding target. Remaining: ${remainingFunding}`
      });
    }

    // Check if investor already invested (upsert)
    const existingInvestment = await prisma.investment.findUnique({
      where: { userId_listingId: { userId, listingId } }
    });

    const newTotalFunded = listing.currentFunded + amount;
    const investorNewAmount = (existingInvestment ? existingInvestment.amount : 0) + amount;
    const sharePercentage = (investorNewAmount / listing.fundingTarget) * 100;

    // Determine if fully funded
    const isFullyFunded = newTotalFunded >= listing.fundingTarget;
    const newCampaignStatus = isFullyFunded ? 'FULLY_FUNDED' : listing.campaignStatus;

    // Use a transaction to ensure atomicity
    const result = await prisma.$transaction(async (tx) => {
      // 1. Deduct wallet balance (Will throw error if insufficient balance)
      const newWalletBalance = await deductWalletForInvestment(tx, {
        userId,
        amount,
        listingId,
        description: `Investment in ${listing.title || 'Product Shares'}`,
      });

      // 2. Upsert the investment
      const investment = await tx.investment.upsert({
        where: { userId_listingId: { userId, listingId } },
        create: {
          userId,
          listingId,
          amount,
          sharePercentage
        },
        update: {
          amount: investorNewAmount,
          sharePercentage
        }
      });

      // 3. Update listing's currentFunded and campaignStatus
      const updatedListing = await tx.listing.update({
        where: { id: listingId },
        data: {
          currentFunded: newTotalFunded,
          campaignStatus: newCampaignStatus
        }
      });

      // 4. Recalculate all investors' share percentages
      if (listing.fundingTarget > 0) {
        const allInvestments = await tx.investment.findMany({
          where: { listingId }
        });
        for (const inv of allInvestments) {
          await tx.investment.update({
            where: { id: inv.id },
            data: { sharePercentage: (inv.amount / listing.fundingTarget) * 100 }
          });
        }
      }

      return { investment, updatedListing, newWalletBalance };
    });

    res.status(201).json({
      investment: result.investment,
      listing: {
        id: result.updatedListing.id,
        currentFunded: result.updatedListing.currentFunded,
        fundingTarget: result.updatedListing.fundingTarget,
        campaignStatus: result.updatedListing.campaignStatus,
        fundingPercentage: (result.updatedListing.currentFunded / result.updatedListing.fundingTarget) * 100
      }
    });

    if (isFullyFunded && listing.campaignStatus !== 'FULLY_FUNDED') {
      try {
        const watchers = await prisma.watchlist.findMany({
          where: {
            listingId,
            alertOnFunded: true
          },
          include: { user: true }
        });
        const { sendWatchlistAlert } = require('../services/notificationService');
        for (const watch of watchers) {
          await sendWatchlistAlert(
            watch.user,
            result.updatedListing,
            'FUNDED',
            `The product "${result.updatedListing.assetName}" has reached 100% funding!`
          );
        }
      } catch (err) {
        console.error('Failed to send watchlist notifications:', err);
      }
    }

  } catch (error) {
    console.error('Error creating investment:', error);
    res.status(500).json({ error: 'Failed to create investment' });
  }
}

// GET /api/investments/my - Get all investments for current investor
async function getMyInvestments(req, res) {
  const userId = req.user.id;

  try {
    const investments = await prisma.investment.findMany({
      where: { userId },
      include: {
        listing: {
          select: {
            id: true,
            assetName: true,
            category: true,
            fundingTarget: true,
            currentFunded: true,
            rentalPrice: true,
            campaignStatus: true,
            isDelivered: true,
            storageLocation: true,
            imageUrls: true,
            description: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = investments.map(inv => ({
      id: inv.id,
      amount: inv.amount,
      sharePercentage: inv.sharePercentage,
      createdAt: inv.createdAt,
      listing: inv.listing,
      fundingPercentage: (inv.listing.currentFunded / inv.listing.fundingTarget) * 100
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching investments:', error);
    res.status(500).json({ error: 'Failed to fetch investments' });
  }
}

// GET /api/listings/:id/investments - Get all investors for a listing
async function getListingInvestors(req, res) {
  const { id } = req.params;

  try {
    const investments = await prisma.investment.findMany({
      where: { listingId: id },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true
          }
        }
      },
      orderBy: { sharePercentage: 'desc' }
    });

    const listing = await prisma.listing.findUnique({
      where: { id },
      select: { fundingTarget: true, currentFunded: true, campaignStatus: true }
    });

    res.json({
      investors: investments.map(inv => ({
        id: inv.id,
        userId: inv.userId,
        investorName: inv.user.fullName,
        amount: inv.amount,
        sharePercentage: inv.sharePercentage,
        createdAt: inv.createdAt
      })),
      fundingSummary: listing ? {
        fundingTarget: listing.fundingTarget,
        currentFunded: listing.currentFunded,
        fundingPercentage: (listing.currentFunded / listing.fundingTarget) * 100,
        campaignStatus: listing.campaignStatus
      } : null
    });
  } catch (error) {
    console.error('Error fetching listing investors:', error);
    res.status(500).json({ error: 'Failed to fetch listing investors' });
  }
}

// GET /api/listings/:id/funding-status - Get funding progress
async function getFundingStatus(req, res) {
  const { id } = req.params;

  try {
    const listing = await prisma.listing.findUnique({
      where: { id },
      select: {
        id: true,
        assetName: true,
        fundingTarget: true,
        currentFunded: true,
        campaignStatus: true,
        isDelivered: true
      }
    });

    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    const investorCount = await prisma.investment.count({ where: { listingId: id } });

    res.json({
      ...listing,
      fundingPercentage: (listing.currentFunded / listing.fundingTarget) * 100,
      investorCount
    });
  } catch (error) {
    console.error('Error fetching funding status:', error);
    res.status(500).json({ error: 'Failed to fetch funding status' });
  }
}

// GET /api/listings/available - Get all listings available for investment
async function getAvailableListings(req, res) {
  try {
    const listings = await prisma.listing.findMany({
      where: {
        status: 'active',
        campaignStatus: { in: ['funding', 'FUNDING'] }
      },
      include: {
        producer: {
          select: { id: true, fullName: true }
        },
        _count: {
          select: { investments: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = listings.map(l => ({
      ...l,
      producerName: l.producer.fullName,
      investorCount: l._count.investments,
      fundingPercentage: l.fundingTarget > 0 ? (l.currentFunded / l.fundingTarget) * 100 : 0,
      producer: undefined,
      _count: undefined
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching available listings:', error);
    res.status(500).json({ error: 'Failed to fetch available listings' });
  }
}

module.exports = {
  createInvestment,
  getMyInvestments,
  getListingInvestors,
  getFundingStatus,
  getAvailableListings
};
