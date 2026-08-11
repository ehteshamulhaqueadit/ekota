const prisma = require('../config/prisma');

// POST /api/rental-pool - List a product in the rental pool
async function listInRentalPool(req, res) {
  const userId = req.user.id;
  const { listingId } = req.body;

  if (!listingId) {
    return res.status(400).json({ error: 'listingId is required' });
  }

  try {
    // Verify the listing exists and is fully funded + delivered
    const listing = await prisma.listing.findUnique({
      where: { id: listingId },
      include: { investments: { where: { userId } } }
    });

    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    // Check if the user is an investor in this product
    if (listing.investments.length === 0) {
      return res.status(403).json({ error: 'Only investors in this product can list it for rent' });
    }

    if (!listing.isDelivered) {
      return res.status(400).json({ error: 'Product must be delivered before listing for rent' });
    }

    // Check if already in rental pool
    const existing = await prisma.rentalPoolItem.findUnique({
      where: { listingId }
    });
    if (existing) {
      return res.status(409).json({ error: 'Product is already listed in the rental pool' });
    }

    const poolItem = await prisma.rentalPoolItem.create({
      data: {
        listingId,
        currentRentPrice: listing.rentalPrice,
        status: 'AVAILABLE'
      },
      include: {
        listing: {
          select: { id: true, assetName: true, category: true, imageUrls: true, description: true }
        }
      }
    });

    res.status(201).json(poolItem);
  } catch (error) {
    console.error('Error listing in rental pool:', error);
    res.status(500).json({ error: 'Failed to list in rental pool' });
  }
}

// GET /api/rental-pool - List all available products for rent
async function getRentalPool(req, res) {
  try {
    const poolItems = await prisma.rentalPoolItem.findMany({
      where: { status: 'AVAILABLE' },
      include: {
        listing: {
          select: {
            id: true,
            assetName: true,
            category: true,
            description: true,
            imageUrls: true,
            specifications: true,
            producer: { select: { fullName: true } }
          }
        }
      },
      orderBy: { listedAt: 'desc' }
    });

    const formatted = poolItems.map(item => ({
      id: item.id,
      listingId: item.listingId,
      currentRentPrice: item.currentRentPrice,
      status: item.status,
      listedAt: item.listedAt,
      assetName: item.listing.assetName,
      category: item.listing.category,
      description: item.listing.description,
      imageUrls: item.listing.imageUrls,
      specifications: item.listing.specifications,
      producerName: item.listing.producer.fullName
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching rental pool:', error);
    res.status(500).json({ error: 'Failed to fetch rental pool' });
  }
}

// POST /api/rental-pool/:id/rent - Rent a product
async function rentProduct(req, res) {
  const userId = req.user.id;
  const { id } = req.params;

  try {
    const poolItem = await prisma.rentalPoolItem.findUnique({
      where: { id },
      include: { listing: true }
    });

    if (!poolItem) return res.status(404).json({ error: 'Rental pool item not found' });
    if (poolItem.status !== 'AVAILABLE') {
      return res.status(400).json({ error: 'This product is currently not available for rent' });
    }

    // Create rental and update pool item status
    const result = await prisma.$transaction(async (tx) => {
      const rental = await tx.rental.create({
        data: {
          renterId: userId,
          poolItemId: id,
          startDate: new Date(),
          dailyRate: poolItem.currentRentPrice,
          isActive: true
        }
      });

      const updatedPoolItem = await tx.rentalPoolItem.update({
        where: { id },
        data: { status: 'RENTED' }
      });

      return { rental, updatedPoolItem };
    });

    res.status(201).json({
      rental: result.rental,
      message: 'Product rented successfully'
    });
  } catch (error) {
    console.error('Error renting product:', error);
    res.status(500).json({ error: 'Failed to rent product' });
  }
}

// POST /api/rental-pool/:id/return - Return a rented product
async function returnProduct(req, res) {
  const userId = req.user.id;
  const { id } = req.params;

  try {
    // Find the active rental for this user and pool item
    const rental = await prisma.rental.findFirst({
      where: {
        poolItemId: id,
        renterId: userId,
        isActive: true
      }
    });

    if (!rental) {
      return res.status(404).json({ error: 'No active rental found for this product' });
    }

    const endDate = new Date();
    const daysRented = Math.max(1, Math.ceil((endDate - rental.startDate) / (1000 * 60 * 60 * 24)));
    const totalCost = daysRented * rental.dailyRate;

    const result = await prisma.$transaction(async (tx) => {
      const updatedRental = await tx.rental.update({
        where: { id: rental.id },
        data: {
          endDate,
          totalCost,
          isActive: false
        }
      });

      const updatedPoolItem = await tx.rentalPoolItem.update({
        where: { id },
        data: { status: 'AVAILABLE' }
      });

      return { updatedRental, updatedPoolItem };
    });

    res.json({
      rental: result.updatedRental,
      daysRented,
      totalCost,
      message: 'Product returned successfully'
    });
  } catch (error) {
    console.error('Error returning product:', error);
    res.status(500).json({ error: 'Failed to return product' });
  }
}

// GET /api/rentals/my - Get renter's active/past rentals
async function getMyRentals(req, res) {
  const userId = req.user.id;

  try {
    const rentals = await prisma.rental.findMany({
      where: { renterId: userId },
      include: {
        poolItem: {
          include: {
            listing: {
              select: {
                id: true,
                assetName: true,
                category: true,
                imageUrls: true,
                description: true
              }
            }
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = rentals.map(r => ({
      id: r.id,
      startDate: r.startDate,
      endDate: r.endDate,
      dailyRate: r.dailyRate,
      totalCost: r.totalCost,
      isActive: r.isActive,
      listing: r.poolItem.listing
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching rentals:', error);
    res.status(500).json({ error: 'Failed to fetch rentals' });
  }
}

module.exports = {
  listInRentalPool,
  getRentalPool,
  rentProduct,
  returnProduct,
  getMyRentals
};
