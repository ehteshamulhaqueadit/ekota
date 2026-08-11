const prisma = require('../config/prisma');

// POST /api/watchlist - Add asset to watchlist
async function addToWatchlist(req, res) {
  const userId = req.user.id;
  const { listingId, alertOnAvailable = true, alertOnPriceChange = true, alertOnFunded = true } = req.body;

  try {
    const listing = await prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    const watch = await prisma.watchlist.upsert({
      where: {
        userId_listingId: { userId, listingId }
      },
      update: {
        alertOnAvailable,
        alertOnPriceChange,
        alertOnFunded
      },
      create: {
        userId,
        listingId,
        alertOnAvailable,
        alertOnPriceChange,
        alertOnFunded
      }
    });

    res.status(200).json({ message: 'Added to watchlist', watch });
  } catch (error) {
    console.error('Error adding to watchlist:', error);
    res.status(500).json({ error: 'Failed to add to watchlist' });
  }
}

// DELETE /api/watchlist/:listingId - Remove asset from watchlist
async function removeFromWatchlist(req, res) {
  const userId = req.user.id;
  const { listingId } = req.params;

  try {
    await prisma.watchlist.delete({
      where: {
        userId_listingId: { userId, listingId }
      }
    });
    res.json({ message: 'Removed from watchlist' });
  } catch (error) {
    // If it doesn't exist, ignore
    res.json({ message: 'Removed from watchlist' });
  }
}

// PUT /api/watchlist/:listingId - Update alert configuration
async function updateWatchlistAlerts(req, res) {
  const userId = req.user.id;
  const { listingId } = req.params;
  const { alertOnAvailable, alertOnPriceChange, alertOnFunded } = req.body;

  try {
    const watch = await prisma.watchlist.update({
      where: {
        userId_listingId: { userId, listingId }
      },
      data: {
        ...(alertOnAvailable !== undefined && { alertOnAvailable }),
        ...(alertOnPriceChange !== undefined && { alertOnPriceChange }),
        ...(alertOnFunded !== undefined && { alertOnFunded }),
      }
    });

    res.json({ message: 'Watchlist alerts updated', watch });
  } catch (error) {
    console.error('Error updating watchlist:', error);
    res.status(500).json({ error: 'Failed to update watchlist alerts' });
  }
}

// GET /api/watchlist/my - Get all watched assets for the logged-in user
async function getMyWatchlist(req, res) {
  const userId = req.user.id;
  try {
    const watchlists = await prisma.watchlist.findMany({
      where: { userId },
      include: {
        listing: {
          include: {
            producer: { select: { fullName: true } },
            rentalPoolItem: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.json(watchlists);
  } catch (error) {
    console.error('Error fetching watchlist:', error);
    res.status(500).json({ error: 'Failed to fetch watchlist' });
  }
}

module.exports = {
  addToWatchlist,
  removeFromWatchlist,
  updateWatchlistAlerts,
  getMyWatchlist
};
