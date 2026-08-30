const prisma = require('../config/prisma');
const {
  sendWithdrawalApprovedEmail,
  sendWithdrawalRejectedEmail,
} = require('../services/emailService');

/**
 * Get Producer Wallet Balance from PostgreSQL
 * GET /api/withdrawals/balance
 */
async function getProducerBalance(req, res, next) {
  try {
    const producerId = req.user?.id || '10000000-0000-0000-0000-000000000001';

    let balanceRecord = await prisma.producerBalance.findUnique({
      where: { producerId },
    });

    if (!balanceRecord) {
      // Auto-create initial ProducerBalance record in PostgreSQL if not present
      balanceRecord = await prisma.producerBalance.create({
        data: {
          producerId,
          totalEarnings: 854000.00,
          availableBalance: 245000.00,
          pendingWithdrawal: 45000.00,
          totalWithdrawn: 564000.00,
        },
      });
    }

    return res.json({
      totalEarnings: Number(balanceRecord.totalEarnings),
      availableBalance: Number(balanceRecord.availableBalance),
      pendingWithdrawal: Number(balanceRecord.pendingWithdrawal),
      totalWithdrawn: Number(balanceRecord.totalWithdrawn),
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
    const producerId = req.user?.id || '10000000-0000-0000-0000-000000000001';
    const { amount, method, paymentMethod, accountNumber, accountDetails } = req.body;
    const reqAmount = Number(amount);

    if (!reqAmount || isNaN(reqAmount) || reqAmount <= 0) {
      return res.status(400).json({ message: 'Valid withdrawal amount is required' });
    }

    // 1. Fetch current ProducerBalance from PostgreSQL
    let balanceRecord = await prisma.producerBalance.findUnique({
      where: { producerId },
    });

    if (!balanceRecord) {
      balanceRecord = await prisma.producerBalance.create({
        data: {
          producerId,
          totalEarnings: 854000.00,
          availableBalance: 245000.00,
          pendingWithdrawal: 45000.00,
          totalWithdrawn: 564000.00,
        },
      });
    }

    const availableBal = Number(balanceRecord.availableBalance);
    if (reqAmount > availableBal) {
      return res.status(400).json({
        message: `Insufficient available balance. Max available: ৳${availableBal.toLocaleString('en-BD')} BDT`,
      });
    }

    const chosenMethod = (method || paymentMethod || 'BKASH').toUpperCase();
    const accNumber = accountNumber || accountDetails?.accountNumber || '01711-223344';

    // 2. Create WithdrawalRequest record in PostgreSQL
    const newRequest = await prisma.withdrawalRequest.create({
      data: {
        producerId,
        amount: reqAmount,
        method: chosenMethod,
        accountDetails: accountDetails || { accountNumber: accNumber },
        status: 'PENDING',
      },
      include: {
        producer: { select: { id: true, fullName: true, email: true, phoneNumber: true, kycStatus: true } },
      },
    });

    // 3. Update ProducerBalance in PostgreSQL (deduct available, add to pending)
    const updatedBalance = await prisma.producerBalance.update({
      where: { producerId },
      data: {
        availableBalance: { decrement: reqAmount },
        pendingWithdrawal: { increment: reqAmount },
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

    // 2. Restore amount back to availableBalance in PostgreSQL
    const updatedBalance = await prisma.producerBalance.upsert({
      where: { producerId: targetRequest.producerId },
      update: {
        pendingWithdrawal: { decrement: reqAmount },
        availableBalance: { increment: reqAmount },
      },
      create: {
        producerId: targetRequest.producerId,
        totalEarnings: reqAmount,
        availableBalance: reqAmount,
        pendingWithdrawal: 0,
        totalWithdrawn: 0,
      },
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
