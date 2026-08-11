const prisma = require('../config/prisma');

// In-memory fallback balance and requests initialized with valid PostgreSQL UUIDs
let liveProducerBalance = {
  totalEarnings: 854000.0,
  availableBalance: 245000.0,
  pendingWithdrawal: 45000.0,
  totalWithdrawn: 564000.0,
};

let liveRequests = [
  {
    id: '30000000-0000-0000-0000-000000000001',
    producerId: '10000000-0000-0000-0000-000000000001',
    producer: {
      id: '10000000-0000-0000-0000-000000000001',
      fullName: 'Karim Agro',
      email: 'producer_karim@ekota.com',
      phoneNumber: '+8801700000001',
      kycStatus: 'VERIFIED',
      avatarInitials: 'KA',
    },
    amount: 45000,
    method: 'BKASH',
    paymentMethod: 'BKASH',
    accountDetails: { accountNumber: '01711-223344' },
    accountNumber: '01711-223344',
    walletBalance: 245000,
    requestDate: 'Aug 10, 2026',
    status: 'PENDING',
    createdAt: new Date().toISOString(),
  },
  {
    id: '30000000-0000-0000-0000-000000000002',
    producerId: '10000000-0000-0000-0000-000000000004',
    producer: {
      id: '10000000-0000-0000-0000-000000000004',
      fullName: 'Amina Organic Farms',
      email: 'amina_farms@ekota.com',
      phoneNumber: '+8801500000004',
      kycStatus: 'VERIFIED',
      avatarInitials: 'AF',
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
      try {
        const balanceRecord = await prisma.producerBalance.findUnique({
          where: { producerId },
        });
        if (balanceRecord) {
          return res.json({
            totalEarnings: Number(balanceRecord.totalEarnings),
            availableBalance: Number(balanceRecord.availableBalance),
            pendingWithdrawal: Number(balanceRecord.pendingWithdrawal),
            totalWithdrawn: Number(balanceRecord.totalWithdrawn),
          });
        }
      } catch (_e) {}
    }

    return res.json(liveProducerBalance);
  } catch (error) {
    return next(error);
  }
}

/**
 * Request a Withdrawal (POST /api/withdrawals/request)
 */
async function requestWithdrawal(req, res, next) {
  try {
    const { amount, method, paymentMethod, accountNumber, accountDetails, note } = req.body;
    const reqAmount = Number(amount);

    if (!reqAmount || isNaN(reqAmount) || reqAmount <= 0) {
      return res.status(400).json({ message: 'Valid withdrawal amount is required' });
    }

    if (reqAmount > liveProducerBalance.availableBalance) {
      return res.status(400).json({ message: 'Insufficient available balance' });
    }

    const chosenMethod = (method || paymentMethod || 'BKASH').toUpperCase();
    const newReqId = `30000000-0000-0000-0000-${Date.now().toString().slice(-12)}`;

    const newReq = {
      id: newReqId,
      producerId: req.user?.id || '10000000-0000-0000-0000-000000000001',
      producer: {
        id: req.user?.id || '10000000-0000-0000-0000-000000000001',
        fullName: req.user?.fullName || 'Karim Agro',
        email: req.user?.email || 'producer_karim@ekota.com',
        phoneNumber: req.user?.phoneNumber || '01711-223344',
        kycStatus: req.user?.kycStatus || 'VERIFIED',
        avatarInitials: 'KA',
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
    liveProducerBalance.availableBalance -= reqAmount;
    liveProducerBalance.pendingWithdrawal += reqAmount;

    try {
      if (req.user?.id) {
        await prisma.withdrawalRequest.create({
          data: {
            id: newReqId,
            producerId: req.user.id,
            amount: reqAmount,
            method: chosenMethod,
            accountDetails: accountDetails || { accountNumber: accountNumber || '01711-223344' },
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
 * Get My Requests (GET /api/withdrawals/my)
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
      dbRequests = await prisma.withdrawalRequest.findMany({
        include: { producer: true },
        orderBy: { createdAt: 'desc' },
      });
    } catch (_e) {}

    const map = new Map();

    // 1. Initial live requests map
    for (const r of liveRequests) {
      map.set(r.id, r);
    }

    // 2. Override with DB state for all records
    for (const dbR of dbRequests) {
      const existing = map.get(dbR.id) || {};
      const updatedItem = {
        ...existing,
        id: dbR.id,
        producerId: dbR.producerId,
        producer: dbR.producer || existing.producer || { fullName: 'Karim Agro', email: 'producer_karim@ekota.com', kycStatus: 'VERIFIED' },
        amount: Number(dbR.amount),
        method: dbR.method,
        accountNumber: dbR.accountDetails?.accountNumber || existing.accountNumber || '01711-223344',
        status: dbR.status,
        adminNote: dbR.adminNote || existing.adminNote,
        requestDate: existing.requestDate || new Date(dbR.createdAt).toLocaleDateString(),
        createdAt: dbR.createdAt,
      };
      map.set(dbR.id, updatedItem);

      // Keep liveRequests array in sync
      const idx = liveRequests.findIndex(r => r.id === dbR.id);
      if (idx !== -1) {
        liveRequests[idx] = updatedItem;
      } else {
        liveRequests.push(updatedItem);
      }
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

    // 1. Update in DB directly
    try {
      const dbMatch = await prisma.withdrawalRequest.findFirst({
        where: { id: id }
      });
      if (dbMatch) {
        const updatedDB = await prisma.withdrawalRequest.update({
          where: { id: dbMatch.id },
          data: { status: 'APPROVED', adminNote: req.body?.adminNote || 'Approved for payout' },
        });
        target = { ...dbMatch, status: 'APPROVED', adminNote: req.body?.adminNote || 'Approved for payout' };
      }
    } catch (err) {
      console.warn('[WithdrawalController] DB approve error:', err.message);
    }

    // 2. Update in memory liveRequests
    let reqIndex = liveRequests.findIndex(r => r.id === id);
    if (reqIndex !== -1) {
      liveRequests[reqIndex].status = 'APPROVED';
      liveRequests[reqIndex].adminNote = req.body?.adminNote || 'Approved for payout';
      liveRequests[reqIndex].processedAt = new Date().toISOString();
      if (!target) target = liveRequests[reqIndex];
    } else if (target) {
      liveRequests.unshift(target);
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

    // 1. Update in DB directly
    try {
      const dbMatch = await prisma.withdrawalRequest.findFirst({
        where: { id: id }
      });
      if (dbMatch) {
        const updatedDB = await prisma.withdrawalRequest.update({
          where: { id: dbMatch.id },
          data: { status: 'REJECTED', adminNote: adminNote || 'Rejected by administrator' },
        });
        target = { ...dbMatch, status: 'REJECTED', adminNote: adminNote || 'Rejected by administrator' };
      }
    } catch (err) {
      console.warn('[WithdrawalController] DB reject error:', err.message);
    }

    // 2. Update in memory liveRequests
    let reqIndex = liveRequests.findIndex(r => r.id === id);
    if (reqIndex !== -1) {
      liveRequests[reqIndex].status = 'REJECTED';
      liveRequests[reqIndex].adminNote = adminNote || 'Rejected by administrator';
      liveRequests[reqIndex].processedAt = new Date().toISOString();
      if (!target) target = liveRequests[reqIndex];
    } else if (target) {
      liveRequests.unshift(target);
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
