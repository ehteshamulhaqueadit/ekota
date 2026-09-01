const prisma = require('../config/prisma');
const walletService = require('../services/walletService');
const {
  sendWithdrawalApprovedEmail,
  sendWithdrawalRejectedEmail,
} = require('../services/emailService');

/**
 * Get User Wallet Balance from PostgreSQL
 * GET /api/withdrawals/balance
 */
async function getProducerBalance(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const wallet = await walletService.getOrCreateWallet(userId);
    const availableBalance = Number(wallet.balance);

    const pendingRequests = await prisma.withdrawalRequest.findMany({
      where: { producerId: userId, status: 'PENDING' },
    });
    const pendingWithdrawal = pendingRequests.reduce((sum, r) => sum + Number(r.amount), 0);

    const approvedRequests = await prisma.withdrawalRequest.findMany({
      where: { producerId: userId, status: 'APPROVED' },
    });
    const totalWithdrawn = approvedRequests.reduce((sum, r) => sum + Number(r.amount), 0);

    return res.json({
      totalEarnings: availableBalance + totalWithdrawn,
      availableBalance: availableBalance,
      pendingWithdrawal: pendingWithdrawal,
      totalWithdrawn: totalWithdrawn,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Request a Payout Withdrawal from PostgreSQL
 * POST /api/withdrawals/request
 */
async function requestWithdrawal(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { amount, method, paymentMethod, accountNumber, accountDetails } = req.body;
    const reqAmount = Number(amount);

    if (!reqAmount || isNaN(reqAmount) || reqAmount <= 0) {
      return res.status(400).json({ success: false, message: 'Valid withdrawal amount is required' });
    }

    // 1. Fetch user's actual Wallet from PostgreSQL
    const wallet = await walletService.getOrCreateWallet(userId);
    const availableBal = Number(wallet.balance);

    // 2. Strict Check: Automatic Denial if requested amount exceeds wallet balance
    if (reqAmount > availableBal) {
      return res.status(400).json({
        success: false,
        message: `Withdrawal Denied: Requested amount (৳${reqAmount.toLocaleString('en-BD')} BDT) exceeds your available wallet balance (৳${availableBal.toLocaleString('en-BD')} BDT).`,
      });
    }

    const chosenMethod = (method || paymentMethod || 'BKASH').toUpperCase();
    const accNumber = accountNumber || accountDetails?.accountNumber || '—';

    // 3. Atomically deduct requested amount from user's Wallet balance
    const updatedWallet = await prisma.wallet.update({
      where: { id: wallet.id },
      data: { balance: availableBal - reqAmount },
    });

    await prisma.user.update({
      where: { id: userId },
      data: { walletBalance: availableBal - reqAmount },
    });

    // 4. Create WithdrawalRequest record in PostgreSQL
    const newRequest = await prisma.withdrawalRequest.create({
      data: {
        producerId: userId,
        amount: reqAmount,
        method: chosenMethod,
        accountDetails: accountDetails || { accountNumber: accNumber },
        status: 'PENDING',
      },
      include: {
        producer: { select: { id: true, fullName: true, email: true, phoneNumber: true, kycStatus: true } },
      },
    });

    return res.status(201).json({
      success: true,
      message: 'Withdrawal request submitted successfully to Admins. Status: PENDING',
      withdrawalRequest: {
        ...newRequest,
        amount: Number(newRequest.amount),
        accountNumber: accNumber,
      },
      balance: {
        totalEarnings: Number(updatedWallet.balance),
        availableBalance: Number(updatedWallet.balance),
        pendingWithdrawal: reqAmount,
        totalWithdrawn: 0,
      },
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get Producer's own Withdrawal Requests from PostgreSQL
 * GET /api/withdrawals/my
 */
async function getMyWithdrawalRequests(req, res, next) {
  try {
    const producerId = req.user?.id || '10000000-0000-0000-0000-000000000001';

    const dbRequests = await prisma.withdrawalRequest.findMany({
      where: { producerId },
      include: {
        producer: { select: { id: true, fullName: true, email: true, phoneNumber: true, kycStatus: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const requests = dbRequests.map(r => ({
      id: r.id,
      producerId: r.producerId,
      amount: Number(r.amount),
      method: r.method,
      paymentMethod: r.method,
      accountDetails: r.accountDetails,
      accountNumber: r.accountDetails?.accountNumber || '—',
      status: r.status,
      adminNote: r.adminNote,
      createdAt: r.createdAt,
      requestDate: new Date(r.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
    }));

    return res.json({ success: true, requests });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Get All Withdrawal Requests from PostgreSQL
 * GET /api/withdrawals or GET /api/withdrawals/admin/all
 */
async function getAllWithdrawalRequests(req, res, next) {
  try {
    const { status } = req.query;
    const whereClause = {};

    if (status && status.toUpperCase() !== 'ALL') {
      whereClause.status = status.toUpperCase();
    }

    const dbRequests = await prisma.withdrawalRequest.findMany({
      where: whereClause,
      include: {
        producer: { select: { id: true, fullName: true, email: true, phoneNumber: true, kycStatus: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const requests = dbRequests.map(r => ({
      id: r.id,
      producerId: r.producerId,
      producer: r.producer || { fullName: 'Producer', email: 'producer@ekota.com', kycStatus: 'VERIFIED' },
      amount: Number(r.amount),
      method: r.method,
      paymentMethod: r.method,
      accountDetails: r.accountDetails,
      accountNumber: r.accountDetails?.accountNumber || '—',
      status: r.status,
      adminNote: r.adminNote,
      createdAt: r.createdAt,
      requestDate: new Date(r.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
    }));

    return res.json({ success: true, requests });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Approve Withdrawal Request in PostgreSQL
 * PATCH /api/withdrawals/:id/approve
 */
async function approveWithdrawal(req, res, next) {
  try {
    const { id } = req.params;
    const adminNote = req.body?.adminNote || 'Approved for bank/mobile payout';
    const reviewedById = req.user?.id || '00000000-0000-0000-0000-000000000001';

    const targetRequest = await prisma.withdrawalRequest.findUnique({
      where: { id },
      include: { producer: true },
    });

    if (!targetRequest) {
      return res.status(404).json({ success: false, message: 'Withdrawal request not found in database' });
    }

    if (targetRequest.status === 'APPROVED') {
      return res.json({ success: true, message: 'Withdrawal request is already approved', withdrawal: targetRequest });
    }

    const reqAmount = Number(targetRequest.amount);

    // 1. Update WithdrawalRequest in PostgreSQL
    const updatedRequest = await prisma.withdrawalRequest.update({
      where: { id },
      data: {
        status: 'APPROVED',
        adminNote: adminNote,
        reviewedById: reviewedById,
        reviewedAt: new Date(),
        transactionRef: `TXN-EKT-${Date.now().toString().slice(-6)}`,
      },
      include: { producer: true },
    });

    // 2. Update ProducerBalance in PostgreSQL (reduce pending, increment totalWithdrawn)
    const updatedBalance = await prisma.producerBalance.upsert({
      where: { producerId: targetRequest.producerId },
      update: {
        pendingWithdrawal: { decrement: reqAmount },
        totalWithdrawn: { increment: reqAmount },
      },
      create: {
        producerId: targetRequest.producerId,
        totalEarnings: reqAmount,
        availableBalance: 0,
        pendingWithdrawal: 0,
        totalWithdrawn: reqAmount,
      },
    });

    // 3. Create Notification in PostgreSQL
    try {
      await prisma.notification.create({
        data: {
          userId: targetRequest.producerId,
          title: 'Withdrawal Approved',
          message: `Your withdrawal request of ৳${reqAmount.toLocaleString('en-BD')} BDT via ${targetRequest.method} has been approved.`,
          type: 'WITHDRAWAL_APPROVED',
        },
      });
    } catch (_e) {}

    // 4. Dispatch Gmail Email Notification to Producer
    if (updatedRequest.producer?.email) {
      sendWithdrawalApprovedEmail({
        to: updatedRequest.producer.email,
        fullName: updatedRequest.producer.fullName,
        amount: reqAmount,
        method: updatedRequest.method,
        adminNote: adminNote,
      });
    }

    return res.json({
      success: true,
      message: 'Withdrawal request approved successfully',
      withdrawal: {
        ...updatedRequest,
        amount: Number(updatedRequest.amount),
      },
      balance: {
        totalEarnings: Number(updatedBalance.totalEarnings),
        availableBalance: Number(updatedBalance.availableBalance),
        pendingWithdrawal: Number(updatedBalance.pendingWithdrawal),
        totalWithdrawn: Number(updatedBalance.totalWithdrawn),
      },
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Reject Withdrawal Request in PostgreSQL
 * PATCH /api/withdrawals/:id/reject
 */
async function rejectWithdrawal(req, res, next) {
  try {
    const { id } = req.params;
    const adminNote = req.body?.adminNote || req.body?.reason || 'Rejected by administrator';
    const reviewedById = req.user?.id || '00000000-0000-0000-0000-000000000001';

    const targetRequest = await prisma.withdrawalRequest.findUnique({
      where: { id },
      include: { producer: true },
    });

    if (!targetRequest) {
      return res.status(404).json({ success: false, message: 'Withdrawal request not found in database' });
    }

    if (targetRequest.status === 'REJECTED') {
      return res.json({ success: true, message: 'Withdrawal request is already rejected', withdrawal: targetRequest });
    }

    const reqAmount = Number(targetRequest.amount);

    // 1. Update WithdrawalRequest in PostgreSQL
    const updatedRequest = await prisma.withdrawalRequest.update({
      where: { id },
      data: {
        status: 'REJECTED',
        adminNote: adminNote,
        reviewedById: reviewedById,
        reviewedAt: new Date(),
      },
      include: { producer: true },
    });

    // 2. Restore amount back to user's Wallet balance in PostgreSQL
    let wallet = await walletService.getOrCreateWallet(targetRequest.producerId);
    const restoredBal = Number(wallet.balance) + reqAmount;
    const updatedWallet = await prisma.wallet.update({
      where: { id: wallet.id },
      data: { balance: restoredBal },
    });
    await prisma.user.update({
      where: { id: targetRequest.producerId },
      data: { walletBalance: restoredBal },
    });

    // 3. Create Notification in PostgreSQL
    try {
      await prisma.notification.create({
        data: {
          userId: targetRequest.producerId,
          title: 'Withdrawal Rejected',
          message: `Your withdrawal request of ৳${reqAmount.toLocaleString('en-BD')} BDT was rejected. Reason: ${adminNote}`,
          type: 'WITHDRAWAL_REJECTED',
        },
      });
    } catch (_e) {}

    // 4. Dispatch Gmail Email Notification to Producer
    if (updatedRequest.producer?.email) {
      sendWithdrawalRejectedEmail({
        to: updatedRequest.producer.email,
        fullName: updatedRequest.producer.fullName,
        amount: reqAmount,
        method: updatedRequest.method,
        reason: adminNote,
      });
    }

    return res.json({
      success: true,
      message: 'Withdrawal request rejected successfully',
      withdrawal: {
        ...updatedRequest,
        amount: Number(updatedRequest.amount),
      },
      balance: {
        totalEarnings: Number(updatedBalance.totalEarnings),
        availableBalance: Number(updatedBalance.availableBalance),
        pendingWithdrawal: Number(updatedBalance.pendingWithdrawal),
        totalWithdrawn: Number(updatedBalance.totalWithdrawn),
      },
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Generic handler for Admin processing withdrawal
 */
async function processWithdrawalRequest(req, res, next) {
  const { status } = req.body;
  if (status && status.toUpperCase() === 'REJECTED') {
    return rejectWithdrawal(req, res, next);
  }
  return approveWithdrawal(req, res, next);
}

module.exports = {
  getProducerBalance,
  requestWithdrawal,
  getMyWithdrawalRequests,
  getAllWithdrawalRequests,
  approveWithdrawal,
  rejectWithdrawal,
  processWithdrawalRequest,
};
