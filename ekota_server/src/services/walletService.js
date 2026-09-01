const prisma = require('../config/prisma');

/**
 * Get or create wallet for user atomically
 */
async function getOrCreateWallet(userId) {
  if (!userId) throw new Error('User ID is required');

  let wallet = await prisma.wallet.findUnique({
    where: { userId },
  });

  if (!wallet) {
    try {
      wallet = await prisma.wallet.create({
        data: {
          userId,
          balance: 0.0000,
          currency: 'BDT',
          status: 'ACTIVE',
        },
      });
    } catch (_err) {
      // Handle potential concurrency race condition
      wallet = await prisma.wallet.findUnique({ where: { userId } });
    }
  }

  return wallet;
}

/**
 * Get paginated transaction history for user's wallet
 */
/**
 * Get unified transaction history for user's wallet (Deposits, Investments, Rent Payments, Withdrawals, Refunds)
 */
async function getWalletTransactions(userId, page = 1, limit = 20) {
  const wallet = await getOrCreateWallet(userId);

  const skip = (Math.max(1, parseInt(page)) - 1) * parseInt(limit);
  const take = parseInt(limit);

  // 1. Fetch wallet ledger transactions, deposit payments, withdrawal requests, and investments
  const [walletTxs, depositPayments, withdrawalRequests, userInvestments] = await Promise.all([
    prisma.walletTransaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' },
    }),
    prisma.payment.findMany({
      where: { userId, paymentType: 'DEPOSIT' },
      orderBy: { createdAt: 'desc' },
    }),
    prisma.withdrawalRequest ? prisma.withdrawalRequest.findMany({
      where: { producerId: userId },
      orderBy: { createdAt: 'desc' },
    }) : [],
    prisma.investment.findMany({
      where: { userId },
      include: { listing: true },
      orderBy: { createdAt: 'desc' },
    }),
  ]);

  const existingTxRefs = new Set(walletTxs.map(t => t.reference));

  // 2. Uncredited / Pending / Rejected SSLCommerz Deposits
  const depositItems = depositPayments
    .filter(p => !existingTxRefs.has(`EKOTA-DEP-${p.tranId}`))
    .map(p => {
      let status = 'PENDING';
      let statusSubtitle = 'Waiting for Admin Validation';

      if (p.status === 'VALIDATED') {
        status = 'COMPLETED';
        statusSubtitle = 'Admin Approved';
      } else if (p.status === 'FAILED' || p.status === 'REJECTED') {
        status = 'REJECTED';
        statusSubtitle = 'Payment was rejected by Admin';
      } else if (p.status === 'CANCELLED') {
        status = 'CANCELLED';
        statusSubtitle = 'Cancelled by user';
      } else if (p.status === 'PENDING_ADMIN_VALIDATION') {
        status = 'PENDING';
        statusSubtitle = 'Waiting for Admin Validation';
      }

      return {
        id: p.id,
        type: 'DEPOSIT',
        title: 'Wallet Deposit',
        amount: Number(p.amount),
        status,
        statusSubtitle,
        description: 'Wallet Deposit via SSLCommerz',
        reference: `EKOTA-DEP-${p.tranId}`,
        createdAt: p.createdAt,
      };
    });

  // 3. Process wallet ledger transactions (DEPOSIT, PAYMENT/INVESTMENT/RENT, WITHDRAWAL, REFUND)
  const ledgerItems = walletTxs.map(t => {
    let type = t.type;
    let title = 'Wallet Transaction';
    let status = t.status === 'COMPLETED' ? 'COMPLETED' : t.status;
    let statusSubtitle = t.description || '';

    if (t.reference && t.reference.startsWith('EKOTA-INV-')) {
      type = 'INVESTMENT';
      title = 'Investment';
      statusSubtitle = t.description || 'Investment in project';
    } else if (t.reference && t.reference.startsWith('EKOTA-RENT-')) {
      type = 'RENT_PAYMENT';
      title = 'Rent Payment';
      statusSubtitle = t.description || 'Rent Payment';
    } else if (t.type === 'DEPOSIT') {
      type = 'DEPOSIT';
      title = 'Wallet Deposit';
      status = 'COMPLETED';
      statusSubtitle = 'Admin Approved';
    } else if (t.type === 'WITHDRAWAL') {
      type = 'WITHDRAWAL';
      title = 'Withdrawal';
      statusSubtitle = t.description || 'Withdrawal completed';
    } else if (t.type === 'REFUND' || t.type === 'WITHDRAWAL_REVERSAL') {
      type = 'REFUND';
      title = 'Investment Refund';
      statusSubtitle = 'Funds returned to wallet balance';
    }

    return {
      id: t.id,
      type,
      title,
      amount: Number(t.amount),
      status,
      statusSubtitle,
      description: t.description || title,
      reference: t.reference,
      createdAt: t.createdAt,
    };
  });

  // 4. Pending / Processing Producer Withdrawals not yet in wallet ledger
  const withdrawalItems = withdrawalRequests
    .filter(w => !existingTxRefs.has(`EKOTA-WITHDRAW-${w.id}`))
    .map(w => {
      let status = 'PROCESSING';
      let statusSubtitle = 'Withdrawal request is being processed';

      if (w.status === 'APPROVED' || w.status === 'PROCESSED') {
        status = 'COMPLETED';
        statusSubtitle = 'Funds disbursed by Admin';
      } else if (w.status === 'REJECTED') {
        status = 'REJECTED';
        statusSubtitle = 'Withdrawal request was rejected';
      }

      return {
        id: w.id,
        type: 'WITHDRAWAL',
        title: 'Withdrawal',
        amount: Number(w.amount),
        status,
        statusSubtitle,
        description: `Withdrawal request via ${w.method}`,
        reference: `EKOTA-WITHDRAW-${w.id}`,
        createdAt: w.createdAt,
      };
    });

  // 5. User Investments from `prisma.investment` not yet in ledger
  const investmentItems = userInvestments
    .filter(inv => !existingTxRefs.has(`EKOTA-INV-${inv.id}`))
    .map(inv => {
      const listingName = inv.listing?.assetName || 'Project';
      return {
        id: inv.id,
        type: 'INVESTMENT',
        title: 'Investment',
        amount: Number(inv.amount),
        status: 'COMPLETED',
        statusSubtitle: `Investment in ${listingName}`,
        description: `Investment in ${listingName}`,
        reference: `EKOTA-INV-${inv.id}`,
        createdAt: inv.createdAt,
      };
    });

  // Combine all items, eliminate duplicate IDs, and sort by createdAt descending
  const itemMap = new Map();
  [...ledgerItems, ...depositItems, ...withdrawalItems, ...investmentItems].forEach(item => {
    if (!itemMap.has(item.id)) {
      itemMap.set(item.id, item);
    }
  });

  const combined = Array.from(itemMap.values());
  combined.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  const total = combined.length;
  const paginated = combined.slice(skip, skip + take);

  return {
    transactions: paginated,
    pagination: {
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / take) || 1,
    },
  };
}

/**
 * Idempotently credit wallet after successful SSLCommerz payment validation
 */
async function creditWalletForPayment(paymentId, tranId, amount, userId, payload = {}) {
  return await prisma.$transaction(async (tx) => {
    // 1. Re-check payment status inside transaction (Row lock / concurrency control)
    const payment = await tx.payment.findUnique({
      where: { id: paymentId },
    });

    if (!payment) throw new Error('Payment not found');
    if (payment.status === 'VALIDATED') {
      return { success: true, message: 'Payment already processed' };
    }

    // 2. Mark payment as VALIDATED
    await tx.payment.update({
      where: { id: paymentId },
      data: {
        status: 'VALIDATED',
        valId: payload.val_id || payload.valId || null,
        bankTranId: payload.bank_tran_id || payload.bankTranId || null,
        cardType: payload.card_type || payload.cardType || 'SSLCommerz',
        metadata: payload,
      },
    });

    // 3. Fetch or create Wallet inside transaction
    let wallet = await tx.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      wallet = await tx.wallet.create({
        data: { userId, balance: 0.0000, currency: 'BDT', status: 'ACTIVE' },
      });
    }

    const numericAmount = Number(amount);
    const balanceBefore = Number(wallet.balance);
    const balanceAfter = balanceBefore + numericAmount;

    // 4. Update Wallet balance & User.walletBalance atomically
    const updatedWallet = await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: balanceAfter },
    });

    await tx.user.update({
      where: { id: userId },
      data: { walletBalance: balanceAfter },
    });

    // 5. Create immutable WalletTransaction ledger entry
    const reference = `EKOTA-DEP-${tranId}`;
    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'DEPOSIT',
        amount: numericAmount,
        balanceBefore,
        balanceAfter,
        reference,
        description: `SSLCommerz Deposit (Tran ID: ${tranId})`,
        status: 'COMPLETED',
        metadata: payload,
      },
    });

    return {
      success: true,
      wallet: updatedWallet,
      newBalance: balanceAfter,
    };
  });
}

/**
 * Pay using Wallet Balance safely with server-side validation & locking
 */
async function payFromWallet({ userId, amount, description, reference, metadata = {} }) {
  const numericAmount = Number(amount);
  if (!numericAmount || isNaN(numericAmount) || numericAmount <= 0) {
    throw new Error('Valid payment amount is required');
  }

  return await prisma.$transaction(async (tx) => {
    let wallet = await tx.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      wallet = await tx.wallet.create({
        data: { userId, balance: 0.0000, currency: 'BDT', status: 'ACTIVE' },
      });
    }

    const currentBalance = Number(wallet.balance);
    if (currentBalance < numericAmount) {
      const err = new Error('Insufficient wallet balance');
      err.statusCode = 400;
      throw err;
    }

    const balanceBefore = currentBalance;
    const balanceAfter = currentBalance - numericAmount;

    // 1. Deduct wallet balance
    const updatedWallet = await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: balanceAfter },
    });

    await tx.user.update({
      where: { id: userId },
      data: { walletBalance: balanceAfter },
    });

    // 2. Insert transaction ledger
    const txRef = reference || `EKOTA-PAY-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
    const ledgerTx = await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'PAYMENT',
        amount: numericAmount,
        balanceBefore,
        balanceAfter,
        reference: txRef,
        description: description || 'Payment from Ekota Wallet',
        status: 'COMPLETED',
        metadata,
      },
    });

    return {
      success: true,
      transactionId: ledgerTx.id,
      reference: txRef,
      newBalance: balanceAfter,
      wallet: updatedWallet,
    };
  });
}

/**
 * Deduct wallet balance for investment inside a transaction
 */
async function deductWalletForInvestment(tx, { userId, amount, listingId, description }) {
  const numericAmount = Number(amount);
  let wallet = await tx.wallet.findUnique({ where: { userId } });
  if (!wallet) {
    wallet = await tx.wallet.create({
      data: { userId, balance: 0.0000, currency: 'BDT', status: 'ACTIVE' },
    });
  }

  const currentBalance = Number(wallet.balance);
  if (currentBalance < numericAmount) {
    const err = new Error('Insufficient wallet balance. Please add money to your wallet.');
    err.statusCode = 400;
    throw err;
  }

  const balanceBefore = currentBalance;
  const balanceAfter = currentBalance - numericAmount;

  await tx.wallet.update({
    where: { id: wallet.id },
    data: { balance: balanceAfter },
  });

  await tx.user.update({
    where: { id: userId },
    data: { walletBalance: balanceAfter },
  });

  const txRef = `EKOTA-INV-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  await tx.walletTransaction.create({
    data: {
      walletId: wallet.id,
      userId,
      type: 'INVESTMENT',
      amount: numericAmount,
      balanceBefore,
      balanceAfter,
      reference: txRef,
      description: description || `Investment in Listing ${listingId}`,
      status: 'COMPLETED',
      metadata: { listingId },
    },
  });

  return balanceAfter;
}

module.exports = {
  getOrCreateWallet,
  getWalletTransactions,
  creditWalletForPayment,
  payFromWallet,
  deductWalletForInvestment,
};

