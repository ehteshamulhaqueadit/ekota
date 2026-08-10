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
    if (req.user?.id) {
      try {
        const requests = await prisma.withdrawalRequest.findMany({
          where: { producerId: req.user.id },
          orderBy: { createdAt: 'desc' },
        });
        if (requests && requests.length > 0) {
          return res.json({ success: true, requests });
        }
      } catch (_e) {}
    }

    return res.json({ success: true, requests: liveRequests });
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

    try {
      const where = status && status !== 'ALL' ? { status: status.toUpperCase() } : {};
      const dbRequests = await prisma.withdrawalRequest.findMany({
        where,
        include: { producer: true },
        orderBy: { createdAt: 'desc' },
      });
      if (dbRequests && dbRequests.length > 0) {
        return res.json({ success: true, requests: dbRequests });
      }
    } catch (_e) {}

    let filtered = liveRequests;
    if (status && status !== 'ALL') {
      filtered = liveRequests.filter(r => r.status.toUpperCase() === status.toUpperCase());
    }

    return res.json({ success: true, requests: filtered });
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
    const reqIndex = liveRequests.findIndex(r => r.id === id || r.id.includes(id));

    if (reqIndex === -1) {
      return res.status(404).json({ success: false, message: 'Withdrawal request not found' });
    }

    const existing = liveRequests[reqIndex];

    // Enforce Double Processing Prevention
    if (existing.status !== 'PENDING') {
      return res.status(409).json({
        success: false,
        message: `Withdrawal request has already been processed with status: ${existing.status}`,
      });
    }

    existing.status = 'APPROVED';
    existing.processedAt = new Date().toISOString();
    existing.processedBy = req.user?.id || 'admin-01';
    existing.transactionRef = `TXN-EKT-${Math.floor(100000 + Math.random() * 900000)}`;

    const amt = Number(existing.amount);
    liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
    liveProducerBalance.totalWithdrawn += amt;

    // Create Notification record
    try {
      if (existing.producerId) {
        await prisma.notification.create({
          data: {
            userId: existing.producerId,
            title: 'Withdrawal Approved',
            message: `Your withdrawal request of ৳${amt.toLocaleString()} has been approved.`,
            type: 'WITHDRAWAL_APPROVED',
          },
        });
      }
    } catch (_e) {}

    sendNotificationEmail({
      to: existing.producer?.email || 'producer@ekota.com.bd',
      subject: `Ekota Payout Update - Withdrawal Request Approved`,
      title: `Withdrawal Request Approved`,
      message: `Your withdrawal request of ৳${amt.toLocaleString()} has been approved. Transaction Ref: ${existing.transactionRef}`,
    });

    return res.json({
      success: true,
      message: `Withdrawal request of ৳${amt} approved successfully`,
      withdrawal: existing,
      balance: liveProducerBalance,
    });
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
    const { adminNote } = req.body;

    const reqIndex = liveRequests.findIndex(r => r.id === id || r.id.includes(id));
    if (reqIndex === -1) {
      return res.status(404).json({ success: false, message: 'Withdrawal request not found' });
    }

    const existing = liveRequests[reqIndex];

    // Enforce Double Processing Prevention
    if (existing.status !== 'PENDING') {
      return res.status(409).json({
        success: false,
        message: `Withdrawal request has already been processed with status: ${existing.status}`,
      });
    }

    existing.status = 'REJECTED';
    existing.adminNote = adminNote || 'Rejected by administrator';
    existing.processedAt = new Date().toISOString();
    existing.processedBy = req.user?.id || 'admin-01';

    const amt = Number(existing.amount);
    liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
    liveProducerBalance.availableBalance += amt;

    // Create Notification record
    try {
      if (existing.producerId) {
        await prisma.notification.create({
          data: {
            userId: existing.producerId,
            title: 'Withdrawal Rejected',
            message: `Your withdrawal request of ৳${amt.toLocaleString()} has been rejected. Note: ${existing.adminNote}`,
            type: 'WITHDRAWAL_REJECTED',
          },
        });
      }
    } catch (_e) {}

    sendNotificationEmail({
      to: existing.producer?.email || 'producer@ekota.com.bd',
      subject: `Ekota Payout Update - Withdrawal Request Rejected`,
      title: `Withdrawal Request Rejected`,
      message: `Your withdrawal request of ৳${amt.toLocaleString()} has been rejected. Reason: ${existing.adminNote}`,
    });

    return res.json({
      success: true,
      message: `Withdrawal request of ৳${amt} rejected successfully`,
      withdrawal: existing,
      balance: liveProducerBalance,
    });
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
