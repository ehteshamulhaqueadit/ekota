const prisma = require('../config/prisma');

// Fee calculation constants
const BASE_FEE = 500;         // BDT base monthly fee
const SIZE_RATE = 0.05;       // BDT per cubic cm
const WEIGHT_RATE = 10;       // BDT per kg
const PRICE_PERCENTAGE = 0.01; // 1% of product price

function calculateMonthlyFee(listing) {
  const sizeFee = (listing.sizeCubicCm || 0) * SIZE_RATE;
  const weightFee = (listing.weightKg || 0) * WEIGHT_RATE;
  const priceFee = (listing.fundingTarget || 0) * PRICE_PERCENTAGE;
  return Math.round((BASE_FEE + sizeFee + weightFee + priceFee) * 100) / 100;
}

// POST /api/warehouse/store - Move product to warehouse
async function storeInWarehouse(req, res) {
  const userId = req.user.id;
  const { listingId } = req.body;

  if (!listingId) {
    return res.status(400).json({ error: 'listingId is required' });
  }

  try {
    const listing = await prisma.listing.findUnique({
      where: { id: listingId },
      include: { investments: { where: { userId } } }
    });

    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    if (listing.investments.length === 0) {
      return res.status(403).json({ error: 'Only investors in this product can manage warehouse storage' });
    }

    if (!listing.isDelivered) {
      return res.status(400).json({ error: 'Product must be delivered before warehouse storage' });
    }

    // Check if already in warehouse
    const existing = await prisma.warehouseStorage.findUnique({
      where: { listingId }
    });
    if (existing && existing.isActive) {
      return res.status(409).json({ error: 'Product is already in warehouse' });
    }

    const monthlyFee = calculateMonthlyFee(listing);

    const result = await prisma.$transaction(async (tx) => {
      const storage = existing
        ? await tx.warehouseStorage.update({
            where: { listingId },
            data: { isActive: true, monthlyFee, storedAt: new Date() }
          })
        : await tx.warehouseStorage.create({
            data: { listingId, monthlyFee, isActive: true }
          });

      await tx.listing.update({
        where: { id: listingId },
        data: { storageLocation: 'WAREHOUSE' }
      });

      return storage;
    });

    res.status(201).json({
      storage: result,
      monthlyFee,
      feeBreakdown: {
        baseFee: BASE_FEE,
        sizeFee: (listing.sizeCubicCm || 0) * SIZE_RATE,
        weightFee: (listing.weightKg || 0) * WEIGHT_RATE,
        priceFee: (listing.fundingTarget || 0) * PRICE_PERCENTAGE
      },
      message: `Product stored in warehouse. Monthly fee: ${monthlyFee} BDT`
    });
  } catch (error) {
    console.error('Error storing in warehouse:', error);
    res.status(500).json({ error: 'Failed to store in warehouse' });
  }
}

// POST /api/warehouse/retrieve - Retrieve product from warehouse
async function retrieveFromWarehouse(req, res) {
  const userId = req.user.id;
  const { listingId } = req.body;

  if (!listingId) {
    return res.status(400).json({ error: 'listingId is required' });
  }

  try {
    const listing = await prisma.listing.findUnique({
      where: { id: listingId },
      include: { investments: { where: { userId } } }
    });

    if (!listing) return res.status(404).json({ error: 'Listing not found' });
    if (listing.investments.length === 0) {
      return res.status(403).json({ error: 'Only investors can manage warehouse storage' });
    }

    const storage = await prisma.warehouseStorage.findUnique({
      where: { listingId }
    });

    if (!storage || !storage.isActive) {
      return res.status(400).json({ error: 'Product is not currently in warehouse' });
    }

    await prisma.$transaction(async (tx) => {
      await tx.warehouseStorage.update({
        where: { listingId },
        data: { isActive: false }
      });

      await tx.listing.update({
        where: { id: listingId },
        data: { storageLocation: 'HOME' }
      });
    });

    res.json({ message: 'Product retrieved from warehouse successfully' });
  } catch (error) {
    console.error('Error retrieving from warehouse:', error);
    res.status(500).json({ error: 'Failed to retrieve from warehouse' });
  }
}

// GET /api/warehouse/fees/:listingId - Get warehouse fee for a product
async function getWarehouseFee(req, res) {
  const { listingId } = req.params;

  try {
    const listing = await prisma.listing.findUnique({
      where: { id: listingId }
    });

    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    const monthlyFee = calculateMonthlyFee(listing);

    const storage = await prisma.warehouseStorage.findUnique({
      where: { listingId }
    });

    res.json({
      listingId,
      assetName: listing.assetName,
      monthlyFee,
      feeBreakdown: {
        baseFee: BASE_FEE,
        sizeFee: (listing.sizeCubicCm || 0) * SIZE_RATE,
        weightFee: (listing.weightKg || 0) * WEIGHT_RATE,
        priceFee: (listing.fundingTarget || 0) * PRICE_PERCENTAGE
      },
      currentlyInWarehouse: storage ? storage.isActive : false,
      storedAt: storage ? storage.storedAt : null
    });
  } catch (error) {
    console.error('Error fetching warehouse fee:', error);
    res.status(500).json({ error: 'Failed to fetch warehouse fee' });
  }
}

// GET /api/warehouse/my - List all my products in warehouse
async function getMyWarehouseItems(req, res) {
  const userId = req.user.id;

  try {
    // Find all listings the user has invested in that are in warehouse
    const investments = await prisma.investment.findMany({
      where: { userId },
      include: {
        listing: {
          include: {
            warehouseStorage: true
          }
        }
      }
    });

    const warehouseItems = investments
      .filter(inv => inv.listing.warehouseStorage && inv.listing.warehouseStorage.isActive)
      .map(inv => ({
        listingId: inv.listing.id,
        assetName: inv.listing.assetName,
        category: inv.listing.category,
        imageUrls: inv.listing.imageUrls,
        mySharePercentage: inv.sharePercentage,
        monthlyFee: inv.listing.warehouseStorage.monthlyFee,
        storedAt: inv.listing.warehouseStorage.storedAt,
        lastFeePaidAt: inv.listing.warehouseStorage.lastFeePaidAt
      }));

    res.json(warehouseItems);
  } catch (error) {
    console.error('Error fetching warehouse items:', error);
    res.status(500).json({ error: 'Failed to fetch warehouse items' });
  }
}

module.exports = {
  storeInWarehouse,
  retrieveFromWarehouse,
  getWarehouseFee,
  getMyWarehouseItems
};
