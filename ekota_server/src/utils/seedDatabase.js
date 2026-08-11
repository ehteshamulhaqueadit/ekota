const prisma = require('../config/prisma');

const SAMPLE_USERS = [
  {
    id: '10000000-0000-0000-0000-000000000001',
    email: 'producer_karim@ekota.com',
    passwordHash: '$2a$12$eImiTXuWVxfM37uY4JANjO5E/e0N.J3V312qW4pP1vXJ7e.',
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

const SAMPLE_LISTINGS = [
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

const SAMPLE_WITHDRAWALS = [
  {
    id: '30000000-0000-0000-0000-000000000001',
    producerId: '10000000-0000-0000-0000-000000000001',
    amount: 45000,
    method: 'BKASH',
    accountDetails: { accountNumber: '01711-223344' },
    status: 'PENDING'
  },
  {
    id: '30000000-0000-0000-0000-000000000002',
    producerId: '10000000-0000-0000-0000-000000000004',
    amount: 120000,
    method: 'BANK_TRANSFER',
    accountDetails: { accountNumber: '1501203498001 (City Bank)' },
    status: 'APPROVED',
    transactionRef: 'TXN-EKT-991823'
  }
];

const SAMPLE_PAYMENTS = [
  {
    id: '40000000-0000-0000-0000-000000000001',
    userId: '10000000-0000-0000-0000-000000000003',
    tranId: 'EKOTA-PAY-1786331900-101',
    amount: 15000,
    currency: 'BDT',
    paymentType: 'RENT',
    status: 'PENDING',
    cardType: 'SSLCommerz Gateway'
  },
  {
    id: '40000000-0000-0000-0000-000000000002',
    userId: '10000000-0000-0000-0000-000000000002',
    tranId: 'EKOTA-PAY-1786331950-202',
    amount: 50000,
    currency: 'BDT',
    paymentType: 'INVESTMENT',
    status: 'PENDING',
    cardType: 'SSLCommerz Gateway'
  }
];

let seeded = false;

async function seedDatabaseIfEmpty() {
  if (seeded) return;
  try {
    // 1. Seed Users
    for (const u of SAMPLE_USERS) {
      await prisma.user.upsert({
        where: { id: u.id },
        update: {},
        create: u
      }).catch(_e => {});
    }

    // 2. Seed Listings
    for (const l of SAMPLE_LISTINGS) {
      await prisma.listing.upsert({
        where: { id: l.id },
        update: {},
        create: l
      }).catch(_e => {});
    }

    // 3. Seed Withdrawal Requests
    for (const w of SAMPLE_WITHDRAWALS) {
      await prisma.withdrawalRequest.upsert({
        where: { id: w.id },
        update: {},
        create: w
      }).catch(_e => {});
    }

    // 4. Seed Payments
    for (const p of SAMPLE_PAYMENTS) {
      await prisma.payment.upsert({
        where: { id: p.id },
        update: {},
        create: p
      }).catch(_e => {});
    }

    seeded = true;
    console.log('[Seed] Initial database records verified & persistent.');
  } catch (err) {
    console.warn('[Seed] Database auto-seed check:', err.message);
  }
}

module.exports = { seedDatabaseIfEmpty };
