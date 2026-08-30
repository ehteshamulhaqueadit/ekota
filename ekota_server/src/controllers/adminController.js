const prisma = require('../config/prisma');
const {
  sendAccountBlockedEmail,
  sendAccountUnblockedEmail,
  sendProducerWarningEmail
} = require('../services/emailService');

// Initial seed data definitions
const initialSampleUsers = [
  {
    id: '10000000-0000-0000-0000-000000000001',
    email: 'producer_karim@ekota.com',
    passwordHash: '$2a$12$eImiTXuWVxfM37uY4JANjO5E/e0N.J3V312qW4pP1vXJ7e.', // dummy hash
    fullName: 'Karim Agro',
    phoneNumber: '+8801700000001',
    role: 'PRODUCER',
    isBlocked: false,
    blockedReason: null,
    kycStatus: 'VERIFIED'
  },
  {
    id: '10000000-0000-0000-0000-000000000002',
    email: 'investor_tariq@ekota.com',
    passwordHash: '$2a$12$eImiTXuWVxfM37uY4JANjO5E/e0N.J3V312qW4pP1vXJ7e.',
    fullName: 'Tariq Rahman',
    phoneNumber: '+8801800000002',
    role: 'INVESTOR',
    isBlocked: false,
    blockedReason: null,
    kycStatus: 'VERIFIED'
  },
  {
    id: '10000000-0000-0000-0000-000000000003',
    email: 'renter_rahim@ekota.com',
    passwordHash: '$2a$12$eImiTXuWVxfM37uY4JANjO5E/e0N.J3V312qW4pP1vXJ7e.',
    fullName: 'Rahim Transport',
    phoneNumber: '+8801900000003',
    role: 'RENTER',
    isBlocked: true,
    blockedReason: 'Pending verification documents investigation',
    kycStatus: 'PENDING'
  },
  {
    id: '10000000-0000-0000-0000-000000000004',
    email: 'amina_farms@ekota.com',
    passwordHash: '$2a$12$eImiTXuWVxfM37uY4JANjO5E/e0N.J3V312qW4pP1vXJ7e.',
    fullName: 'Amina Organic Farms',
    phoneNumber: '+8801500000004',
    role: 'PRODUCER',
    isBlocked: false,
    blockedReason: null,
    kycStatus: 'VERIFIED'
  }
];

const initialSampleListings = [
  {
    id: '20000000-0000-0000-0000-000000000001',
    assetName: 'Automatic Rice Harvester 5000',
    category: 'Agricultural Machinery',
    fundingTarget: 250000,
    rentalPrice: 1500,
    description: 'High efficiency paddy harvester available for seasonal lease.',
    specifications: 'Engine: 75HP Diesel, Fuel Capacity: 60L',
    imageUrls: ['https://images.unsplash.com/photo-1592982537447-7440770cbfc9'],
    videoUrls: [],
    productionTimeType: 'scheduled',
    productionDays: 14,
    status: 'active',
    campaignStatus: 'funding',
    upvotes: 18,
    downvotes: 1,
    producerId: '10000000-0000-0000-0000-000000000001'
  },
  {
    id: '20000000-0000-0000-0000-000000000002',
    assetName: 'Solar Powered Cold Storage Facility',
    category: 'Storage & Logistics',
    fundingTarget: 500000,
    rentalPrice: 3000,
    description: 'Temperature-controlled preservation unit for fruits and vegetables.',
    specifications: 'Capacity: 10 Metric Tons, Temp Range: 2°C to 10°C',
    imageUrls: ['https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d'],
    videoUrls: [],
    productionTimeType: 'instant',
    productionDays: 0,
    status: 'active',
    campaignStatus: 'funding',
    upvotes: 42,
    downvotes: 0,
    producerId: '10000000-0000-0000-0000-000000000001'
  },
  {
    id: '20000000-0000-0000-0000-000000000003',
    assetName: 'Organic Seed & Fertilizer Sprayer',
    category: 'Farming Tools',
    fundingTarget: 80000,
    rentalPrice: 600,
    description: 'Multi-nozzle automated sprayer unit for medium-sized croplands.',
    specifications: 'Tank Volume: 200L, Spray Radius: 12 meters',
    imageUrls: [],
    videoUrls: [],
    productionTimeType: 'instant',
    productionDays: 0,
    status: 'paused',
    campaignStatus: 'funding',
    upvotes: 9,
    downvotes: 0,
    producerId: '10000000-0000-0000-0000-000000000004'
  }
];

const liveUsersMap = new Map(initialSampleUsers.map(u => [u.id, { ...u, createdAt: new Date().toISOString() }]));
const liveListingsMap = new Map(initialSampleListings.map(l => [
  l.id,
  {
    ...l,
    createdAt: new Date().toISOString(),
    producer: liveUsersMap.get(l.producerId)
  }
]));

let isDatabaseSeeded = false;

async function ensureDatabaseSeeded() {
  if (isDatabaseSeeded) return;
  try {
    const userCount = await prisma.user.count();
    if (userCount === 0) {
      for (const u of initialSampleUsers) {
        await prisma.user.upsert({
          where: { id: u.id },
          update: {},
          create: u
        });
      }
    }

    const listingCount = await prisma.listing.count();
    if (listingCount === 0) {
      for (const l of initialSampleListings) {
        await prisma.listing.upsert({
          where: { id: l.id },
          update: {},
          create: l
        });
      }
    }
    isDatabaseSeeded = true;
  } catch (_err) {
    // If DB is unreachable or disconnected, fallback memory store is used
  }
}

/**
 * Get all users (Producers, Investors, Renters, Admins)
 */
async function getUsers(req, res, next) {
  try {
    await ensureDatabaseSeeded();
    const { search, role, isBlocked } = req.query;

    const where = {};
    if (role) where.role = role.toUpperCase();
    if (isBlocked !== undefined && isBlocked !== '') where.isBlocked = isBlocked === 'true';

    if (search) {
      where.OR = [
        { fullName: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
        { phoneNumber: { contains: search, mode: 'insensitive' } }
      ];
    }

    let dbUsers = [];
    try {
      dbUsers = await prisma.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          fullName: true,
          phoneNumber: true,
          role: true,
          isBlocked: true,
          blockedReason: true,
          kycStatus: true,
          createdAt: true,
          updatedAt: true
        },
        orderBy: { createdAt: 'desc' }
      });
    } catch (_dbError) {}

    if (dbUsers && dbUsers.length > 0) {
      for (const u of dbUsers) {
        liveUsersMap.set(u.id, u);
      }
    }

    let users = Array.from(liveUsersMap.values()).filter(u => {
      if (role && u.role !== role.toUpperCase()) return false;
      if (isBlocked !== undefined && isBlocked !== '' && u.isBlocked !== (isBlocked === 'true')) return false;
      if (search) {
        const s = search.toLowerCase();
        return u.fullName.toLowerCase().includes(s) || u.email.toLowerCase().includes(s);
      }
      return true;
    });

    res.json(users);
  } catch (error) {
    next(error);
  }
}

/**
 * Block / freeze a user account
 */
async function blockUser(req, res, next) {
  const { id } = req.params;
  const { reason } = req.body;

  if (!reason || !reason.trim()) {
    return res.status(400).json({ error: 'A reason for blocking the account is required.' });
  }

  try {
    let user = liveUsersMap.get(id);

    try {
      const dbUser = await prisma.user.update({
        where: { id },
        data: {
          isBlocked: true,
          blockedReason: reason.trim()
        }
      });
      user = dbUser;

      await prisma.notification.create({
        data: {
          userId: id,
          title: 'Account Temporarily Blocked',
          message: `Your account has been frozen by an admin. Reason: ${reason.trim()}`,
          type: 'GENERAL'
        }
      });
    } catch (_e) {
      if (!user) {
        user = {
          id,
          email: 'user@ekota.com',
          fullName: 'User Account',
          role: 'PRODUCER',
          isBlocked: true,
          blockedReason: reason.trim(),
          kycStatus: 'VERIFIED',
          createdAt: new Date().toISOString()
        };
      } else {
        user.isBlocked = true;
        user.blockedReason = reason.trim();
      }
    }

    liveUsersMap.set(id, user);

    sendAccountBlockedEmail({
      to: user.email,
      fullName: user.fullName,
      reason: reason.trim()
    });

    res.json({
      message: `Account for ${user.fullName} (${user.email}) has been blocked and frozen.`,
      user
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Unblock / unfreeze a user account
 */
async function unblockUser(req, res, next) {
  const { id } = req.params;

  try {
    let user = liveUsersMap.get(id);

    try {
      const dbUser = await prisma.user.update({
        where: { id },
        data: {
          isBlocked: false,
          blockedReason: null
        }
      });
      user = dbUser;

      await prisma.notification.create({
        data: {
          userId: id,
          title: 'Account Access Restored',
          message: 'Your account has been unblocked by an admin. You can now use all platform features.',
          type: 'GENERAL'
        }
      });
    } catch (_e) {
      if (!user) {
        user = {
          id,
          email: 'user@ekota.com',
          fullName: 'User Account',
          role: 'PRODUCER',
          isBlocked: false,
          blockedReason: null,
          kycStatus: 'VERIFIED',
          createdAt: new Date().toISOString()
        };
      } else {
        user.isBlocked = false;
        user.blockedReason = null;
      }
    }

    liveUsersMap.set(id, user);

    sendAccountUnblockedEmail({
      to: user.email,
      fullName: user.fullName
    });

    res.json({
      message: `Account for ${user.fullName} (${user.email}) has been unblocked.`,
      user
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Get all producer listings / posts
 */
async function getAllListings(req, res, next) {
  try {
    await ensureDatabaseSeeded();
    const { search, status, category } = req.query;

    const where = {};
    if (status) where.status = status;
    if (category) where.category = category;

    if (search) {
      where.OR = [
        { assetName: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { category: { contains: search, mode: 'insensitive' } },
        { producer: { fullName: { contains: search, mode: 'insensitive' } } },
        { producer: { email: { contains: search, mode: 'insensitive' } } }
      ];
    }

    let dbListings = [];
    try {
      dbListings = await prisma.listing.findMany({
        where,
        include: {
          producer: {
            select: {
              id: true,
              fullName: true,
              email: true,
              isBlocked: true
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      });
    } catch (_dbError) {}

    if (dbListings && dbListings.length > 0) {
      for (const l of dbListings) {
        liveListingsMap.set(l.id, l);
      }
    }

    let listings = Array.from(liveListingsMap.values()).filter(l => {
      if (status && l.status !== status) return false;
      if (category && l.category !== category) return false;
      if (search) {
        const s = search.toLowerCase();
        return (
          l.assetName.toLowerCase().includes(s) ||
          l.description.toLowerCase().includes(s) ||
          (l.producer?.fullName && l.producer.fullName.toLowerCase().includes(s))
        );
      }
      return true;
    });

    res.json(listings);
  } catch (error) {
    next(error);
  }
}

/**
 * Edit / Update any details of a producer's post
 */
async function updateListing(req, res, next) {
  const { id } = req.params;
  const updateFields = req.body;

  try {
    let existing = liveListingsMap.get(id) || {
      id,
      assetName: 'Producer Listing',
      category: 'General',
      fundingTarget: 100000,
      rentalPrice: 1000,
      description: '',
      status: 'active',
      campaignStatus: 'funding',
      producerId: '10000000-0000-0000-0000-000000000001',
      producer: {
        id: '10000000-0000-0000-0000-000000000001',
        fullName: 'Karim Agro',
        email: 'producer_karim@ekota.com',
        isBlocked: false
      }
    };

    const updatedListing = {
      ...existing,
      ...updateFields,
      updatedAt: new Date().toISOString()
    };

    try {
      const dbListing = await prisma.listing.update({
        where: { id },
        data: updateFields,
        include: {
          producer: { select: { id: true, fullName: true, email: true } }
        }
      });
      if (dbListing) {
        updatedListing.producer = dbListing.producer || updatedListing.producer;
      }
    } catch (_dbErr) {}

    liveListingsMap.set(id, updatedListing);

    res.json({
      message: `Producer post "${updatedListing.assetName}" updated successfully.`,
      listing: updatedListing
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Delete or remove a producer's post
 */
async function deleteListing(req, res, next) {
  const { id } = req.params;

  try {
    try {
      await prisma.listing.delete({ where: { id } });
    } catch (_dbErr) {}

    liveListingsMap.delete(id);

    res.json({ message: 'Producer post removed successfully', id });
  } catch (error) {
    next(error);
  }
}

/**
 * Notify a producer about an issue with their post
 */
async function notifyProducer(req, res, next) {
  const { id } = req.params;
  const { message: warningNotice } = req.body;

  if (!warningNotice || !warningNotice.trim()) {
    return res.status(400).json({ error: 'Notification message / warning detail is required.' });
  }

  try {
    let listing = liveListingsMap.get(id);

    try {
      const dbListing = await prisma.listing.findUnique({
        where: { id },
        include: { producer: true }
      });
      if (dbListing) listing = dbListing;
    } catch (_e) {}

    if (!listing) {
      listing = {
        id,
        assetName: 'Producer Listing',
        producerId: '10000000-0000-0000-0000-000000000001',
        producer: {
          id: '10000000-0000-0000-0000-000000000001',
          fullName: 'Karim Agro',
          email: 'producer_karim@ekota.com'
        }
      };
    }

    if (listing.producerId) {
      try {
        await prisma.notification.create({
          data: {
            userId: listing.producerId,
            title: `Admin Warning: ${listing.assetName}`,
            message: warningNotice.trim(),
            type: 'GENERAL',
            metadata: { listingId: id, postTitle: listing.assetName }
          }
        });
      } catch (_e) {}
    }

    sendProducerWarningEmail({
      to: listing.producer?.email || 'producer@ekota.com',
      fullName: listing.producer?.fullName || 'Producer',
      postTitle: listing.assetName,
      reason: warningNotice.trim()
    });

    res.json({
      message: `Warning notification sent to producer (${listing.producer?.email || 'Producer'}).`,
      listingId: id,
      producerId: listing.producerId
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Get dynamic Admin Dashboard statistics from PostgreSQL
 */
async function getDashboardStats(req, res, next) {
  try {
    // 1. User metrics
    const totalUsers = await prisma.user.count();
    const producersCount = await prisma.user.count({ where: { role: 'PRODUCER' } });
    const investorsCount = await prisma.user.count({ where: { role: 'INVESTOR' } });
    const rentersCount = await prisma.user.count({ where: { role: 'RENTER' } });
    const blockedCount = await prisma.user.count({ where: { isBlocked: true } });

    // 2. Post metrics
    const totalPosts = await prisma.listing.count();
    const activePosts = await prisma.listing.count({ where: { status: 'active' } });
    const pausedPosts = await prisma.listing.count({ where: { status: 'paused' } });

    // 3. Pending actions
    const pendingWithdrawalsCount = await prisma.withdrawalRequest.count({ where: { status: 'PENDING' } });
    const pendingPaymentsCount = await prisma.payment.count({ where: { status: 'PENDING' } });
    const validatedPaymentsCount = await prisma.payment.count({ where: { status: 'VALIDATED' } });

    // 4. Fetch recent payments, withdrawals, and listings
    const recentPayments = await prisma.payment.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { fullName: true, email: true } } },
    });

    const recentWithdrawals = await prisma.withdrawalRequest.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: { producer: { select: { fullName: true, email: true } } },
    });

    const recentListings = await prisma.listing.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: { producer: { select: { fullName: true, email: true } } },
    });

    // Format unified recent activity timeline
    const activities = [
      ...recentPayments.map(p => ({
        id: `pay-${p.id}`,
        type: 'PAYMENT',
        title: `${p.user?.fullName || 'User'} ${p.status === 'VALIDATED' ? 'completed payment' : 'initiated payment'} of ৳${Number(p.amount).toLocaleString('en-BD')} (${p.paymentType})`,
        status: p.status,
        createdAt: p.createdAt,
      })),
      ...recentWithdrawals.map(w => ({
        id: `wth-${w.id}`,
        type: 'WITHDRAWAL',
        title: `Producer ${w.producer?.fullName || 'Producer'} requested ৳${Number(w.amount).toLocaleString('en-BD')} payout (${w.method})`,
        status: w.status,
        createdAt: w.createdAt,
      })),
      ...recentListings.map(l => ({
        id: `lst-${l.id}`,
        type: 'POST',
        title: `Producer ${l.producer?.fullName || 'Producer'} posted asset "${l.assetName}"`,
        status: l.status,
        createdAt: l.createdAt,
      })),
    ].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()).slice(0, 8);

    return res.json({
      users: {
        total: totalUsers,
        producers: producersCount,
        investors: investorsCount,
        renters: rentersCount,
        blocked: blockedCount,
      },
      posts: {
        total: totalPosts,
        active: activePosts,
        paused: pausedPosts,
      },
      pendingActions: {
        withdrawals: pendingWithdrawalsCount,
        payments: pendingPaymentsCount,
        validatedPayments: validatedPaymentsCount,
      },
      recentActivity: activities,
      recentListings: recentListings.map(l => ({
        id: l.id,
        producerName: l.producer?.fullName || 'Producer',
        assetName: l.assetName,
        category: l.category,
        rentalPrice: Number(l.rentalPrice),
        status: l.status,
        createdAt: l.createdAt,
      })),
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getUsers,
  blockUser,
  unblockUser,
  getAllListings,
  updateListing,
  deleteListing,
  notifyProducer,
  getDashboardStats
};

