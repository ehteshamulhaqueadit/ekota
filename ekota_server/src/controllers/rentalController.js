const prisma = require('../config/prisma');
const crypto = require('crypto');

// Default rental window (in days) used when a renter does not specify one.
const DEFAULT_RENTAL_DAYS = 7;

// Distance in km between two lat/lng points (Haversine)
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

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
// Supports filters via query params:
//   lat, lng, radius (km), category, minPrice, maxPrice, availableOnly
async function getRentalPool(req, res) {
  const currentUserId = req.user?.id;
  const {
    lat,
    lng,
    radius,
    category,
    minPrice,
    maxPrice,
    availableOnly
  } = req.query;

  try {
    // Find pool item IDs that are actively rented by the current user
    let myActiveRentalPoolItemIds = new Set();
    if (currentUserId) {
      const myActiveRentals = await prisma.rental.findMany({
        where: { renterId: currentUserId, isActive: true },
        select: { poolItemId: true }
      });
      myActiveRentalPoolItemIds = new Set(myActiveRentals.map(r => r.poolItemId));
    }

    const poolItems = await prisma.rentalPoolItem.findMany({
      include: {
        listing: {
          select: {
            id: true,
            assetName: true,
            category: true,
            description: true,
            imageUrls: true,
            specifications: true,
            producer: { select: { fullName: true } },
            productLocation: true
          }
        }
      },
      orderBy: { listedAt: 'desc' }
    });

    // Exclude items actively rented by the current user
    const filtered = poolItems.filter(item => !myActiveRentalPoolItemIds.has(item.id));

    // Reference point for distance filtering
    const refLat = lat != null ? parseFloat(lat) : null;
    const refLng = lng != null ? parseFloat(lng) : null;
    const maxRadius = radius != null ? parseFloat(radius) : null;
    const min = minPrice != null ? parseFloat(minPrice) : null;
    const max = maxPrice != null ? parseFloat(maxPrice) : null;

    const formatted = filtered
      .map(item => {
        const loc = item.listing.productLocation;
        const dailyRate = item.currentRentPrice;
        const hourlyRate = Math.round((dailyRate / 24) * 100) / 100;

        let distanceKm = null;
        if (loc && refLat != null && refLng != null) {
          distanceKm = haversineKm(refLat, refLng, loc.latitude, loc.longitude);
        }

        return {
          id: item.id,
          listingId: item.listingId,
          currentRentPrice: dailyRate,
          hourlyRate,
          status: item.status,
          listedAt: item.listedAt,
          assetName: item.listing.assetName,
          category: item.listing.category,
          description: item.listing.description,
          imageUrls: item.listing.imageUrls,
          specifications: item.listing.specifications,
          producerName: item.listing.producer.fullName,
          latitude: loc ? loc.latitude : null,
          longitude: loc ? loc.longitude : null,
          address: loc ? loc.address : null,
          distanceKm: distanceKm != null ? Math.round(distanceKm * 10) / 10 : null
        };
      })
      .filter(item => {
        if (availableOnly === 'true' && item.status !== 'AVAILABLE') return false;
        if (category && item.category !== category) return false;
        if (min != null && item.currentRentPrice < min) return false;
        if (max != null && item.currentRentPrice > max) return false;
        if (maxRadius != null && item.distanceKm != null && item.distanceKm > maxRadius) return false;
        return true;
      });

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
  const { durationDays } = req.body || {};

  try {
    const poolItem = await prisma.rentalPoolItem.findUnique({
      where: { id },
      include: { listing: true }
    });

    if (!poolItem) return res.status(404).json({ error: 'Rental pool item not found' });
    if (poolItem.status !== 'AVAILABLE') {
      return res.status(400).json({ error: 'This product is currently not available for rent' });
    }

    // Rental window: default to 7 days unless the renter specifies otherwise.
    const days = Number.isFinite(Number(durationDays)) && Number(durationDays) > 0
      ? Math.floor(Number(durationDays))
      : DEFAULT_RENTAL_DAYS;
    const startDate = new Date();
    const expectedReturnAt = new Date(startDate.getTime() + days * 24 * 60 * 60 * 1000);
    // Digital gate-pass token encoded in the QR code shown in the renter's portal.
    const gatePassCode = crypto.randomUUID();

    // Create rental and update pool item status
    const result = await prisma.$transaction(async (tx) => {
      const rental = await tx.rental.create({
        data: {
          renterId: userId,
          poolItemId: id,
          startDate,
          expectedReturnAt,
          dailyRate: poolItem.currentRentPrice,
          isActive: true,
          status: 'PENDING_PICKUP',
          gatePassCode
        }
      });

      const updatedPoolItem = await tx.rentalPoolItem.update({
        where: { id },
        data: { status: 'RENTED' }
      });

      // Audit trail: booking confirmed, awaiting warehouse pickup.
      await tx.rentalEvent.create({
        data: {
          rentalId: rental.id,
          type: 'CREATED',
          actorId: userId,
          metadata: { durationDays: days, expectedReturnAt: expectedReturnAt.toISOString() }
        }
      });

      return { rental, updatedPoolItem };
    });

    res.status(201).json({
      rental: result.rental,
      message: 'Rental booked successfully. Show your digital gate-pass at the warehouse to pick up the product.'
    });
  } catch (error) {
    console.error('Error renting product:', error);
    res.status(500).json({ error: 'Failed to rent product' });
  }
}

// POST /api/rental-pool/:id/return - Request a return.
// Generates a fresh return gate-pass — a NEW QR code, separate from the
// pickup gate-pass. The warehouse scans this return QR to verify and finally
// complete the return.
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

    if (rental.status !== 'ACTIVE') {
      return res.status(400).json({ error: 'Product must be picked up before it can be returned' });
    }

    // Generate a fresh return gate-pass — a NEW QR distinct from the pickup QR.
    const returnGatePassCode = crypto.randomUUID();

    const updated = await prisma.rental.update({
      where: { id: rental.id },
      data: { returnGatePassCode }
    });

    // Audit trail: renter requested the return, awaiting warehouse verification.
    await prisma.rentalEvent.create({
      data: {
        rentalId: rental.id,
        type: 'RETURN_REQUESTED',
        actorId: userId,
        metadata: { returnGatePassCode }
      }
    });

    res.json({
      rental: updated,
      returnGatePassCode,
      message: 'Return requested. Show the new return gate-pass QR at the warehouse to complete the return.'
    });
  } catch (error) {
    console.error('Error requesting return:', error);
    res.status(500).json({ error: 'Failed to request return' });
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
        },
        events: {
          orderBy: { createdAt: 'asc' }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = rentals.map(r => ({
      id: r.id,
      poolItemId: r.poolItem.id,
      startDate: r.startDate,
      endDate: r.endDate,
      dailyRate: r.dailyRate,
      totalCost: r.totalCost,
      isActive: r.isActive,
      status: r.status,
      expectedReturnAt: r.expectedReturnAt,
      pickupAt: r.pickupAt,
      returnedAt: r.returnedAt,
      gatePassCode: r.gatePassCode,
      returnGatePassCode: r.returnGatePassCode,
      gatePassScannedAt: r.gatePassScannedAt,
      events: r.events,
      listing: r.poolItem.listing
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Error fetching rentals:', error);
    res.status(500).json({ error: 'Failed to fetch rentals' });
  }
}

// GET /api/rentals/:id/portal - Active rental portal for the renter.
// Returns the live status, countdown deadline, digital gate-pass and the
// full audit trail of warehouse scans.
async function getRentalPortal(req, res) {
  const userId = req.user.id;
  const { id } = req.params;

  try {
    const rental = await prisma.rental.findUnique({
      where: { id },
      include: {
        poolItem: {
          include: {
            listing: {
              select: {
                id: true,
                assetName: true,
                category: true,
                imageUrls: true,
                description: true,
                specifications: true,
                producer: { select: { fullName: true } }
              }
            }
          }
        },
        events: {
          orderBy: { createdAt: 'asc' },
          include: { actor: { select: { id: true, fullName: true, role: true } } }
        },
        pickupVerifiedBy: { select: { id: true, fullName: true, role: true } },
        returnVerifiedBy: { select: { id: true, fullName: true, role: true } }
      }
    });

    if (!rental) return res.status(404).json({ error: 'Rental not found' });
    if (rental.renterId !== userId) {
      return res.status(403).json({ error: 'You do not have access to this rental' });
    }

    res.json({
      id: rental.id,
      poolItemId: rental.poolItemId,
      startDate: rental.startDate,
      endDate: rental.endDate,
      dailyRate: rental.dailyRate,
      totalCost: rental.totalCost,
      isActive: rental.isActive,
      status: rental.status,
      expectedReturnAt: rental.expectedReturnAt,
      pickupAt: rental.pickupAt,
      returnedAt: rental.returnedAt,
      gatePassCode: rental.gatePassCode,
      returnGatePassCode: rental.returnGatePassCode,
      gatePassScannedAt: rental.gatePassScannedAt,
      pickupVerifiedBy: rental.pickupVerifiedBy,
      returnVerifiedBy: rental.returnVerifiedBy,
      events: rental.events,
      listing: rental.poolItem.listing
    });
  } catch (error) {
    console.error('Error fetching rental portal:', error);
    res.status(500).json({ error: 'Failed to fetch rental portal' });
  }
}

// POST /api/rentals/gate-pass/scan - Warehouse gate verification.
// The warehouse manager scans the renter's QR gate-pass. The server decides
// the action from the rental's current lifecycle status:
//   PENDING_PICKUP -> verifies pickup (rental becomes ACTIVE)
//   ACTIVE         -> verifies return (rental becomes RETURNED, pool item freed)
async function scanGatePass(req, res) {
  const actorId = req.user.id;
  const { code } = req.body || {};

  if (!code || typeof code !== 'string') {
    return res.status(400).json({ error: 'A gate-pass code is required' });
  }

  try {
    const trimmed = code.trim();
    const rental = await prisma.rental.findFirst({
      where: {
        OR: [
          { gatePassCode: trimmed },
          { returnGatePassCode: trimmed }
        ]
      },
      include: {
        poolItem: { include: { listing: { select: { id: true, assetName: true } } } },
        renter: { select: { id: true, fullName: true, email: true } }
      }
    });

    if (!rental) {
      return res.status(404).json({ error: 'Invalid gate-pass. No matching rental found.' });
    }

    // Distinguish which QR was scanned: the pickup gate-pass or the return
    // gate-pass generated when the renter requested the return.
    const isReturnCode = rental.returnGatePassCode != null && rental.returnGatePassCode === trimmed;

    // Log every scan for the audit trail.
    await prisma.rentalEvent.create({
      data: {
        rentalId: rental.id,
        type: 'SCANNED',
        actorId,
        metadata: { statusAtScan: rental.status, gatePassType: isReturnCode ? 'return' : 'pickup' }
      }
    });

    if (isReturnCode) {
      // ── Return verification (return gate-pass) ──────────────────────────
      if (rental.status !== 'ACTIVE') {
        return res.status(400).json({
          error: 'This return gate-pass is not active. The rental must be active to return.',
          rental: { id: rental.id, status: rental.status }
        });
      }

      const endDate = new Date();
      const daysRented = Math.max(1, Math.ceil((endDate - rental.startDate) / (1000 * 60 * 60 * 24)));
      const totalCost = daysRented * rental.dailyRate;

      const result = await prisma.$transaction(async (tx) => {
        const r = await tx.rental.update({
          where: { id: rental.id },
          data: {
            status: 'RETURNED',
            endDate,
            totalCost,
            isActive: false,
            returnedAt: endDate,
            returnVerifiedById: actorId,
            gatePassScannedAt: endDate
          }
        });

        const updatedPoolItem = await tx.rentalPoolItem.update({
          where: { id: rental.poolItemId },
          data: { status: 'AVAILABLE' }
        });

        await tx.rentalEvent.create({
          data: {
            rentalId: rental.id,
            type: 'RETURNED',
            actorId,
            metadata: { source: 'warehouse_scan_return_qr', daysRented, totalCost }
          }
        });

        // Notify watchlist subscribers that the product is available again.
        const watchers = await tx.watchlist.findMany({
          where: { listingId: updatedPoolItem.listingId, alertOnAvailable: true },
          include: { user: true }
        });
        const { dispatchWatchlistAlerts } = require('../services/notificationService');
        const enqueued = await dispatchWatchlistAlerts(
          tx,
          watchers,
          rental.poolItem.listing,
          'AVAILABLE',
          'The product "{assetName}" is now available for rent!'
        );
        if (enqueued > 0) {
          console.log(`[Rental] Queued ${enqueued} watchlist notification(s) for gate-pass return of ${updatedPoolItem.listingId}`);
        }

        return { r, updatedPoolItem };
      });

      return res.json({
        success: true,
        action: 'return',
        message: `Return verified. "${rental.poolItem.listing.assetName}" is back in the rental pool.`,
        rental: {
          id: result.r.id,
          status: result.r.status,
          returnedAt: result.r.returnedAt,
          daysRented,
          totalCost,
          assetName: rental.poolItem.listing.assetName,
          renterName: rental.renter.fullName,
          renterEmail: rental.renter.email
        }
      });
    }

    // ── Pickup verification (pickup gate-pass) ────────────────────────────
    if (rental.status !== 'PENDING_PICKUP') {
      return res.status(400).json({
        error: rental.status === 'ACTIVE'
          ? 'This is the pickup gate-pass. Use the return gate-pass to return the product.'
          : 'This rental has already been returned and closed.',
        rental: { id: rental.id, status: rental.status }
      });
    }

    const updated = await prisma.$transaction(async (tx) => {
      const r = await tx.rental.update({
        where: { id: rental.id },
        data: {
          status: 'ACTIVE',
          pickupAt: new Date(),
          pickupVerifiedById: actorId,
          gatePassScannedAt: new Date()
        }
      });
      await tx.rentalEvent.create({
        data: {
          rentalId: rental.id,
          type: 'PICKED_UP',
          actorId,
          metadata: { verifiedAt: new Date().toISOString() }
        }
      });
      return r;
    });

    return res.json({
      success: true,
      action: 'pickup',
      message: `Pickup verified. "${rental.poolItem.listing.assetName}" is now active for ${rental.renter.fullName}.`,
      rental: {
        id: updated.id,
        status: updated.status,
        pickupAt: updated.pickupAt,
        expectedReturnAt: updated.expectedReturnAt,
        assetName: rental.poolItem.listing.assetName,
        renterName: rental.renter.fullName,
        renterEmail: rental.renter.email
      }
    });
  } catch (error) {
    console.error('Error scanning gate-pass:', error);
    res.status(500).json({ error: 'Failed to process gate-pass scan' });
  }
}

module.exports = {
  listInRentalPool,
  getRentalPool,
  rentProduct,
  returnProduct,
  getMyRentals,
  getRentalPortal,
  scanGatePass
};
