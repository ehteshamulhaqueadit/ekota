const prisma = require('../src/config/prisma');

async function seed() {
  console.log('Seeding PostgreSQL database for Ekota Member-2...');

  // Clean existing records if any
  await prisma.notification.deleteMany();
  await prisma.withdrawalRequest.deleteMany();
  await prisma.producerBalance.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.user.deleteMany();

  // Create Users
  const admin = await prisma.user.create({
    data: {
      email: 'admin@ekota.com.bd',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Super Admin',
      phoneNumber: '01700000000',
      role: 'ADMIN',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const nilufar = await prisma.user.create({
    data: {
      email: 'nilufar@ekota.com.bd',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Nilufar Rashidova',
      phoneNumber: '01711-223344',
      role: 'PRODUCER',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const tanvir = await prisma.user.create({
    data: {
      email: 'tanvir@ekota.com.bd',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Tanvir Ahmed',
      phoneNumber: '01817-902233',
      role: 'PRODUCER',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const arif = await prisma.user.create({
    data: {
      email: 'arif@ekota.com.bd',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Arif Chowdhury',
      phoneNumber: '01899-887766',
      role: 'PRODUCER',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const tania = await prisma.user.create({
    data: {
      email: 'tania@ekota.com.bd',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Tania Islam',
      phoneNumber: '01912-345678',
      role: 'PRODUCER',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const melvina = await prisma.user.create({
    data: {
      email: 'melvina@ekota.com.bd',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Melvina Begum',
      phoneNumber: '01755-992211',
      role: 'PRODUCER',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const renter = await prisma.user.create({
    data: {
      email: 'tariq@renter.com',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Tariq Renter',
      phoneNumber: '01700112233',
      role: 'RENTER',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  const investor = await prisma.user.create({
    data: {
      email: 'salma@investor.com',
      passwordHash: '$2a$10$e8.Z/0.r/0.r0.r0.r0.r0.r0.r0.r0',
      fullName: 'Salma Investor',
      phoneNumber: '01800112233',
      role: 'INVESTOR',
      kycStatus: 'VERIFIED',
      isEmailVerified: true,
    },
  });

  // Create Producer Balances
  await prisma.producerBalance.create({
    data: {
      producerId: nilufar.id,
      totalEarnings: 485000.0,
      availableBalance: 342500.0,
      pendingWithdrawal: 142500.0,
      totalWithdrawn: 0.0,
    },
  });

  await prisma.producerBalance.create({
    data: {
      producerId: tanvir.id,
      totalEarnings: 91000.0,
      availableBalance: 46000.0,
      pendingWithdrawal: 45000.0,
      totalWithdrawn: 0.0,
    },
  });

  // Create Withdrawal Requests
  await prisma.withdrawalRequest.create({
    data: {
      producerId: nilufar.id,
      amount: 142500.0,
      method: 'BKASH',
      accountDetails: { mobileNumber: '01711-223344' },
      status: 'PENDING',
    },
  });

  await prisma.withdrawalRequest.create({
    data: {
      producerId: tanvir.id,
      amount: 45000.0,
      method: 'ROCKET',
      accountDetails: { mobileNumber: '01817-902233' },
      status: 'PENDING',
    },
  });

  await prisma.withdrawalRequest.create({
    data: {
      producerId: arif.id,
      amount: 87000.0,
      method: 'NAGAD',
      accountDetails: { mobileNumber: '01899-887766' },
      status: 'APPROVED',
      reviewedById: admin.id,
      reviewedAt: new Date(),
      transactionRef: 'NGD-TXN-88112',
    },
  });

  await prisma.withdrawalRequest.create({
    data: {
      producerId: tania.id,
      amount: 220000.0,
      method: 'BANK_TRANSFER',
      accountDetails: {
        bankName: 'Brac Bank',
        accountNumber: '1501209988001',
        branchName: 'Gulshan Branch',
      },
      status: 'REJECTED',
      reviewedById: admin.id,
      reviewedAt: new Date(),
      adminNote: 'Incomplete bank branch routing details.',
    },
  });

  await prisma.withdrawalRequest.create({
    data: {
      producerId: melvina.id,
      amount: 98500.0,
      method: 'BKASH',
      accountDetails: { mobileNumber: '01755-992211' },
      status: 'PROCESSED',
      reviewedById: admin.id,
      reviewedAt: new Date(),
      transactionRef: 'BKS-99228811',
    },
  });

  // Create Payments
  await prisma.payment.create({
    data: {
      userId: renter.id,
      tranId: 'TXN-95671',
      valId: '24080811223344',
      amount: 244962.0,
      currency: 'BDT',
      paymentType: 'INVESTMENT',
      status: 'VALIDATED',
      cardType: 'bKash-BKash',
      bankTranId: 'BKS-889911',
    },
  });

  await prisma.payment.create({
    data: {
      userId: investor.id,
      tranId: 'EKOTA-PAY-172312389-204',
      valId: '240808987654321',
      amount: 50000.0,
      currency: 'BDT',
      paymentType: 'INVESTMENT',
      status: 'VALIDATED',
      cardType: 'VISA-DBBL',
      bankTranId: 'VISA-992233',
    },
  });

  console.log('Seeding completed successfully!');
}

seed()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
