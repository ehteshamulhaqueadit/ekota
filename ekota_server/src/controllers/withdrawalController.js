const prisma = require('../config/prisma');
const { sendNotificationEmail } = require('../services/emailService');

// In-memory fallback balance and requests for demo/test mode
let liveProducerBalance = {
  totalEarnings: 854000.0,
  availableBalance: 245000.0,
  pendingWithdrawal: 45000.0,
  totalWithdrawn: 564000.0,
};

let liveRequests = [
  {
    id: 'WD-8921',
    producerId: 'prod-01',
    producer: {
      id: 'prod-01',
      fullName: 'Nilufar Rashidova',
      email: 'nilufar@ekota.com.bd',
      phoneNumber: '01711-223344',
      kycStatus: 'VERIFIED',
      avatarInitials: 'NR',
    },
    amount: 45000,
    method: 'BKASH',
    paymentMethod: 'BKASH',
    accountDetails: { accountNumber: '01711-223344' },
    accountNumber: '01711-223344',
    walletBalance: 245000,
    requestDate: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
    status: 'PENDING',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'WD-7810',
    producerId: 'prod-02',
    producer: {
      id: 'prod-02',
      fullName: 'Tanvir Hossain',
      email: 'tanvir@ekota.com.bd',
      phoneNumber: '01822-334455',
      kycStatus: 'VERIFIED',
      avatarInitials: 'TH',
    },
    amount: 120000,
    method: 'BANK_TRANSFER',
    paymentMethod: 'BANK_TRANSFER',
    accountDetails: { accountNumber: '1501203498001 (City Bank)' },
    accountNumber: '1501203498001 (City Bank)',
    walletBalance: 120000,
    requestDate: 'Aug 5, 2026',
    status: 'APPROVED',
    processedAt: 'Aug 6, 2026',
    transactionRef: 'TXN-EKT-991823',
    createdAt: new Date(Date.now() - 86400000 * 2).toISOString(),
  },
];

/**
 * Get Producer Balance (GET /api/withdrawals/balance)
 */
async function getProducerBalance(req, res, next) {
  try {
    const producerId = req.user?.id;
    if (producerId) {
      const balance = await prisma.producerBalance.findUnique({
        where: { producerId },
      });
      if (balance) {
        return res.json({
          totalEarnings: Number(balance.totalEarnings),
          availableBalance: Number(balance.availableBalance),
          pendingWithdrawal: Number(balance.pendingWithdrawal),
          totalWithdrawn: Number(balance.totalWithdrawn),
        });
      }
    }
    return res.json(liveProducerBalance);
  } catch (error) {
    return next(error);
  }
}

/**
 * Request Withdrawal (POST /api/withdrawals or POST /api/withdrawals/request)
 */
async function requestWithdrawal(req, res, next) {
  try {
    const { amount, paymentMethod, method, accountDetails, accountNumber, note } = req.body;
    const reqAmount = Number(amount);
    const chosenMethod = (paymentMethod || method || 'BKASH').toUpperCase();

    if (!reqAmount || reqAmount <= 0) {
      return res.status(400).json({ message: 'Valid positive amount is required' });
    }

    if (reqAmount > liveProducerBalance.availableBalance) {
      return res.status(400).json({ message: 'Insufficient available balance' });
    }

    // Deduct available balance and add to pending
    liveProducerBalance.availableBalance -= reqAmount;
    liveProducerBalance.pendingWithdrawal += reqAmount;

    const producerId = req.user?.id || 'prod-01';

    const newReq = {
      id: `WD-${Math.floor(1000 + Math.random() * 9000)}`,
      producerId,
      producer: {
        id: producerId,
        fullName: req.user?.fullName || 'Nilufar Rashidova',
        email: req.user?.email || 'nilufar@ekota.com.bd',
        phoneNumber: req.user?.phoneNumber || '01711-223344',
        kycStatus: 'VERIFIED',
        avatarInitials: (req.user?.fullName || 'Nilufar Rashidova').split(' ').map(n => n[0]).join(''),
      },
      amount: reqAmount,
      method: chosenMethod,
      paymentMethod: chosenMethod,
      accountDetails: accountDetails || { accountNumber: accountNumber || '01711-223344' },
      accountNumber: accountNumber || '01711-223344',
      walletBalance: liveProducerBalance.availableBalance,
      requestDate: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
      note: note || '',
      status: 'PENDING',
      createdAt: new Date().toISOString(),
    };

    liveRequests.unshift(newReq);

    // Save to DB if connection available
    try {
      if (req.user?.id) {
        await prisma.withdrawalRequest.create({
          data: {
            producerId: req.user.id,
            amount: reqAmount,
            method: chosenMethod,
            accountDetails: accountDetails || { accountNumber },
            status: 'PENDING',
          },
        });
      }
    } catch (_e) {}

    return res.status(201).json({
      success: true,
      message: 'Withdrawal request submitted successfully',
      withdrawalRequest: newReq,
      balance: liveProducerBalance,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get My Requests (GET /api/withdrawals/my or GET /api/withdrawals/my-requests)
 */
async function getMyWithdrawalRequests(req, res, next) {
  try {
    let dbRequests = [];
    if (req.user?.id) {
      try {
        dbRequests = await prisma.withdrawalRequest.findMany({
          where: { producerId: req.user.id },
          orderBy: { createdAt: 'desc' },
        });
      } catch (_e) {}
    }

    const map = new Map();
    for (const r of liveRequests) {
      if (!req.user?.id || r.producerId === req.user.id || r.producer?.email?.toLowerCase() === req.user?.email?.toLowerCase()) {
        map.set(r.id, r);
      }
    }
    for (const dbR of dbRequests) {
      map.set(dbR.id, {
        id: dbR.id,
        producerId: dbR.producerId,
        amount: Number(dbR.amount),
        method: dbR.method,
        accountDetails: dbR.accountDetails || { accountNumber: '01700000000' },
        accountNumber: dbR.accountDetails?.accountNumber || '01700000000',
        status: dbR.status,
        createdAt: dbR.createdAt,
      });
    }

    const list = Array.from(map.values());
    return res.json({ success: true, requests: list.length > 0 ? list : liveRequests });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Get All Withdrawal Requests (GET /api/withdrawals or GET /api/withdrawals/admin/all)
 */
async function getAllWithdrawalRequests(req, res, next) {
  try {
    const { status } = req.query;

    let dbRequests = [];
    try {
      const where = status && status !== 'ALL' ? { status: status.toUpperCase() } : {};
      dbRequests = await prisma.withdrawalRequest.findMany({
        where,
        include: { producer: true },
        orderBy: { createdAt: 'desc' },
      });
    } catch (_e) {}

    const map = new Map();
    for (const r of liveRequests) {
      map.set(r.id, r);
    }
    for (const dbR of dbRequests) {
      map.set(dbR.id, {
        id: dbR.id,
        producerId: dbR.producerId,
        producer: dbR.producer || { fullName: 'Producer Member', email: 'producer@ekota.com' },
        amount: Number(dbR.amount),
        method: dbR.method,
        accountNumber: dbR.accountDetails?.accountNumber || '01700000000',
        status: dbR.status,
        requestDate: new Date(dbR.createdAt).toLocaleDateString(),
        createdAt: dbR.createdAt,
      });
    }

    let list = Array.from(map.values());
    if (status && status !== 'ALL') {
      list = list.filter(r => r.status.toUpperCase() === status.toUpperCase());
    }

    return res.json({ success: true, requests: list });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Approve Withdrawal Request (PATCH /api/withdrawals/:id/approve)
 */
async function approveWithdrawal(req, res, next) {
  try {
    const { id } = req.params;
    let target = null;

    // 1. Update in DB if matched
    try {
      const dbMatch = await prisma.withdrawalRequest.findFirst({
        where: { OR: [{ id: id }, { id: { contains: id } }] }
      });
      if (dbMatch) {
        await prisma.withdrawalRequest.update({
          where: { id: dbMatch.id },
          data: { status: 'APPROVED', adminNote: req.body?.adminNote || 'Approved for payout' },
        });
        target = { ...dbMatch, status: 'APPROVED' };
      }
    } catch (_e) {}

    // 2. Update in memory liveRequests if matched
    let reqIndex = liveRequests.findIndex(r => r.id === id || r.id.includes(id) || id.includes(r.id));
    if (reqIndex !== -1) {
      liveRequests[reqIndex].status = 'APPROVED';
      liveRequests[reqIndex].processedAt = new Date().toISOString();
      if (!target) target = liveRequests[reqIndex];
    }

    if (target) {
      const amt = Number(target.amount || 0);
      liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
      liveProducerBalance.totalWithdrawn += amt;

      try {
        if (target.producerId) {
          await prisma.notification.create({
            data: {
              userId: target.producerId,
              title: 'Withdrawal Approved',
              message: `Your withdrawal request of ৳${amt.toLocaleString()} has been approved.`,
              type: 'WITHDRAWAL_APPROVED',
            },
          });
        }
      } catch (_e) {}

      return res.json({
        success: true,
        message: `Withdrawal request approved successfully`,
        withdrawal: target,
        balance: liveProducerBalance,
      });
    }

    return res.status(404).json({ success: false, message: 'Withdrawal request not found' });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Reject Withdrawal Request (PATCH /api/withdrawals/:id/reject)
 */
async function rejectWithdrawal(req, res, next) {
  try {
    const { id } = req.params;
    const { adminNote } = req.body || {};
    let target = null;

    // 1. Update in DB if matched
    try {
      const dbMatch = await prisma.withdrawalRequest.findFirst({
        where: { OR: [{ id: id }, { id: { contains: id } }] }
      });
      if (dbMatch) {
        await prisma.withdrawalRequest.update({
          where: { id: dbMatch.id },
          data: { status: 'REJECTED', adminNote: adminNote || 'Rejected by administrator' },
        });
        target = { ...dbMatch, status: 'REJECTED', adminNote: adminNote || 'Rejected by administrator' };
      }
    } catch (_e) {}

    // 2. Update in memory liveRequests if matched
    let reqIndex = liveRequests.findIndex(r => r.id === id || r.id.includes(id) || id.includes(r.id));
    if (reqIndex !== -1) {
      liveRequests[reqIndex].status = 'REJECTED';
      liveRequests[reqIndex].adminNote = adminNote || 'Rejected by administrator';
      liveRequests[reqIndex].processedAt = new Date().toISOString();
      if (!target) target = liveRequests[reqIndex];
    }

    if (target) {
      const amt = Number(target.amount || 0);
      liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
      liveProducerBalance.availableBalance += amt;

      try {
        if (target.producerId) {
          await prisma.notification.create({
            data: {
              userId: target.producerId,
              title: 'Withdrawal Rejected',
              message: `Your withdrawal request of ৳${amt.toLocaleString()} has been rejected. Note: ${target.adminNote}`,
              type: 'WITHDRAWAL_REJECTED',
            },
          });
        }
      } catch (_e) {}

      return res.json({
        success: true,
        message: `Withdrawal request rejected successfully`,
        withdrawal: target,
        balance: liveProducerBalance,
      });
    }

    return res.status(404).json({ success: false, message: 'Withdrawal request not found' });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Process Withdrawal Request (Generic route handler)
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
