const prisma = require('../config/prisma');

const LOCATION_MONTHLY_FEE = 200; // BDT per month for live location tracking

// GET /api/location/:listingId - Get current location of a product
async function getProductLocation(req, res) {
  const userId = req.user.id;
  const { listingId } = req.params;

  try {
    // Verify the user has an active subscription or is a renter
    const subscription = await prisma.locationSubscription.findUnique({
      where: { userId_listingId: { userId, listingId } }
    });

    const isInvestor = subscription && subscription.isActive;

    // Also check if user is the active renter
    const activeRental = await prisma.rental.findFirst({
      where: {
        renterId: userId,
        isActive: true,
        poolItem: { listingId }
      }
    });

    if (!isInvestor && !activeRental) {
      return res.status(403).json({
        error: 'You need an active location subscription (investor) or an active rental to view product location'
      });
    }

    const location = await prisma.productLocation.findUnique({
      where: { listingId }
    });

    if (!location) {
      return res.status(404).json({ error: 'No location data available for this product' });
    }

    const listing = await prisma.listing.findUnique({
      where: { id: listingId },
      select: { assetName: true, storageLocation: true }
    });

    res.json({
      listingId,
      assetName: listing?.assetName,
      storageLocation: listing?.storageLocation,
      latitude: location.latitude,
      longitude: location.longitude,
      address: location.address,
      lastUpdated: location.updatedAt
    });
  } catch (error) {
    console.error('Error fetching product location:', error);
    res.status(500).json({ error: 'Failed to fetch product location' });
  }
}

// PUT /api/location/:listingId - Update product location (renter submits GPS)
async function updateProductLocation(req, res) {
  const userId = req.user.id;
  const { listingId } = req.params;
  const { latitude, longitude, address } = req.body;

  if (latitude == null || longitude == null) {
    return res.status(400).json({ error: 'latitude and longitude are required' });
  }

  try {
    // Verify the user is the active renter of this product
    const activeRental = await prisma.rental.findFirst({
      where: {
        renterId: userId,
        isActive: true,
        poolItem: { listingId }
      }
    });

    if (!activeRental) {
      return res.status(403).json({ error: 'Only the active renter can update product location' });
    }

    const location = await prisma.productLocation.upsert({
      where: { listingId },
      create: {
        listingId,
        latitude,
        longitude,
        address: address || null
      },
      update: {
        latitude,
        longitude,
        address: address || null
      }
    });

    res.json({
      location,
      message: 'Product location updated successfully'
    });
  } catch (error) {
    console.error('Error updating product location:', error);
    res.status(500).json({ error: 'Failed to update product location' });
  }
}

// POST /api/location/subscribe/:listingId - Subscribe to live location
async function subscribeToLocation(req, res) {
  const userId = req.user.id;
  const { listingId } = req.params;

  try {
    // Verify the user is an investor
    const investment = await prisma.investment.findUnique({
      where: { userId_listingId: { userId, listingId } }
    });

    if (!investment) {
      return res.status(403).json({ error: 'Only investors in this product can subscribe to live location' });
    }

    // Check existing subscription
    const existing = await prisma.locationSubscription.findUnique({
      where: { userId_listingId: { userId, listingId } }
    });

    if (existing && existing.isActive) {
      return res.status(409).json({ error: 'You already have an active location subscription' });
    }

    const subscription = existing
      ? await prisma.locationSubscription.update({
          where: { userId_listingId: { userId, listingId } },
          data: { isActive: true, monthlyFee: LOCATION_MONTHLY_FEE }
        })
      : await prisma.locationSubscription.create({
          data: {
            userId,
            listingId,
            monthlyFee: LOCATION_MONTHLY_FEE,
            isActive: true
          }
        });

    res.status(201).json({
      subscription,
      monthlyFee: LOCATION_MONTHLY_FEE,
      message: `Subscribed to live location. Monthly fee: ${LOCATION_MONTHLY_FEE} BDT`
    });
  } catch (error) {
    console.error('Error subscribing to location:', error);
    res.status(500).json({ error: 'Failed to subscribe to location' });
  }
}

// DELETE /api/location/subscribe/:listingId - Unsubscribe from live location
async function unsubscribeFromLocation(req, res) {
  const userId = req.user.id;
  const { listingId } = req.params;

  try {
    const subscription = await prisma.locationSubscription.findUnique({
      where: { userId_listingId: { userId, listingId } }
    });

    if (!subscription || !subscription.isActive) {
      return res.status(400).json({ error: 'No active subscription found' });
    }

    await prisma.locationSubscription.update({
      where: { userId_listingId: { userId, listingId } },
      data: { isActive: false }
    });

    res.json({ message: 'Unsubscribed from live location successfully' });
  } catch (error) {
    console.error('Error unsubscribing from location:', error);
    res.status(500).json({ error: 'Failed to unsubscribe from location' });
  }
}

// GET /api/location/subscriptions/my - Get my active location subscriptions
async function getMySubscriptions(req, res) {
  const userId = req.user.id;

  try {
    const subscriptions = await prisma.locationSubscription.findMany({
      where: { userId, isActive: true },
      include: {
        // We need to manually query since there's no direct relation on LocationSubscription to Listing
      }
    });

    // Fetch listing details for each subscription
    const listingIds = subscriptions.map(s => s.listingId);
    const listings = await prisma.listing.findMany({
      where: { id: { in: listingIds } },
      select: {
        id: true,
        assetName: true,
        category: true,
        imageUrls: true,
        storageLocation: true,
        productLocation: true
      }
    });

    const listingMap = {};
    listings.forEach(l => { listingMap[l.id] = l; });

    const formatted = subscriptions.map(s => ({
      id: s.id,
      listingId: s.listingId,
      monthlyFee: s.monthlyFee,
      subscribedAt: s.subscribedAt,
      listing: listingMap[s.listingId] ? {
        assetName: listingMap[s.listingId].assetName,
        category: listingMap[s.listingId].category,
        imageUrls: listingMap[s.listingId].imageUrls,
        storageLocation: listingMap[s.listingId].storageLocation,
        hasLocation: !!listingMap[s.listingId].productLocation
      } : null
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching location subscriptions:', error);
    res.status(500).json({ error: 'Failed to fetch location subscriptions' });
  }
}

module.exports = {
  getProductLocation,
  updateProductLocation,
  subscribeToLocation,
  unsubscribeFromLocation,
  getMySubscriptions
};
