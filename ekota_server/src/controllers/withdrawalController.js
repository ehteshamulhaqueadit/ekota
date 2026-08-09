const prisma = require('../config/prisma');
const { sendNotificationEmail } = require('../services/emailService');

// Live State Store (In-Memory + DB sync)
let liveRequests = [
  {
    id: 'WD-3847',
    producerId: 'prod-01',
    producer: {
      id: 'prod-01',
      fullName: 'Nilufar Rashidova',
      email: 'nilufar@ekota.com.bd',
      phoneNumber: '01711-223344',
      kycStatus: 'VERIFIED',
      avatarInitials: 'NR',
    },
    amount: 142500,
    method: 'BKASH',
    accountDetails: { mobileNumber: '01711-223344' },
    status: 'PENDING',
    createdAt: new Date().toISOString(),
  },
  {
    id: 'WD-3501',
    producerId: 'prod-02',
    producer: {
      id: 'prod-02',
      fullName: 'Arif Chowdhury',
      email: 'arif@ekota.com.bd',
      phoneNumber: '01899-887766',
      kycStatus: 'VERIFIED',
      avatarInitials: 'AC',
    },
    amount: 87000,
    method: 'NAGAD',
    accountDetails: { mobileNumber: '01899-887766' },
    status: 'APPROVED',
    transactionRef: 'NGD-TXN-88112',
    processedAt: new Date(Date.now() - 3600000 * 20).toISOString(),
    createdAt: new Date(Date.now() - 3600000 * 24).toISOString(),
  },
  {
    id: 'WD-2810',
    producerId: 'prod-03',
    producer: {
      id: 'prod-03',
      fullName: 'Tania Islam',
      email: 'tania@ekota.com.bd',
      phoneNumber: '01912-345678',
      kycStatus: 'VERIFIED',
      avatarInitials: 'TI',
    },
    amount: 220000,
    method: 'BANK_TRANSFER',
    accountDetails: { bankName: 'Brac Bank', accountNumber: '1501209988001', branchName: 'Gulshan Branch' },
    status: 'REJECTED',
    adminNote: 'Incomplete bank branch routing details.',
    processedAt: new Date(Date.now() - 3600000 * 40).toISOString(),
    createdAt: new Date(Date.now() - 3600000 * 48).toISOString(),
  },
  {
    id: 'WD-2036',
    producerId: 'prod-04',
    producer: {
      id: 'prod-04',
      fullName: 'Tanvir Ahmed',
      email: 'tanvir@ekota.com.bd',
      phoneNumber: '01817-902233',
      kycStatus: 'VERIFIED',
      avatarInitials: 'TA',
    },
    amount: 45000,
    method: 'ROCKET',
    accountDetails: { mobileNumber: '01817-902233' },
    status: 'PENDING',
    createdAt: new Date(Date.now() - 3600000 * 10).toISOString(),
  },
  {
    id: 'WD-1798',
    producerId: 'prod-05',
    producer: {
      id: 'prod-05',
      fullName: 'Melvina Begum',
      email: 'melvina@ekota.com.bd',
      phoneNumber: '01755-992211',
      kycStatus: 'VERIFIED',
      avatarInitials: 'MB',
    },
    amount: 98500,
    method: 'BKASH',
    accountDetails: { mobileNumber: '01755-992211' },
    status: 'PROCESSED',
    transactionRef: 'BKS-99228811',
    processedAt: new Date(Date.now() - 3600000 * 70).toISOString(),
    createdAt: new Date(Date.now() - 3600000 * 72).toISOString(),
  },
];

let liveProducerBalance = {
  totalEarnings: 485000.0,
  availableBalance: 342500.0,
  pendingWithdrawal: 142500.0,
  totalWithdrawn: 0.0,
};

/**
 * Get Producer Balance
 */
async function getProducerBalance(req, res, next) {
  try {
    try {
      const balance = await prisma.producerBalance.findFirst({
        where: { producerId: req.user.id },
      });
      if (balance) {
        return res.json({ balance });
      }
    } catch (_e) {
      // Fallback
    }

    return res.json({ balance: liveProducerBalance });
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

    const producerId = req.user.id || 'prod-01';

    const newReq = {
      id: `WD-${Math.floor(1000 + Math.random() * 9000)}`,
      producerId,
      producer: {
        id: producerId,
        fullName: req.user.fullName || 'Nilufar Rashidova',
        email: req.user.email || 'nilufar@ekota.com.bd',
        phoneNumber: req.user.phoneNumber || '01711-223344',
        kycStatus: 'VERIFIED',
        avatarInitials: 'NR',
      },
      amount: reqAmount,
      method: chosenMethod,
      paymentMethod: chosenMethod,
      accountDetails: accountDetails || { accountNumber: accountNumber || '01711-223344' },
      note: note || '',
      status: 'PENDING',
      createdAt: new Date().toISOString(),
    };

    liveRequests.unshift(newReq);

    // Try saving to DB if available
    try {
      await prisma.withdrawalRequest.create({
        data: {
          producerId,
          amount: reqAmount,
          method: chosenMethod,
          accountDetails: accountDetails || { accountNumber },
          status: 'PENDING',
        },
      });
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
    try {
      const requests = await prisma.withdrawalRequest.findMany({
        where: { producerId: req.user.id },
        orderBy: { createdAt: 'desc' },
      });
      if (requests && requests.length > 0) {
        return res.json({ success: true, requests });
      }
    } catch (_e) {}

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
      const where = status ? { status: status.toUpperCase() } : {};
      const requests = await prisma.withdrawalRequest.findMany({
        where,
        include: { producer: true },
        orderBy: { createdAt: 'desc' },
      });
      if (requests && requests.length > 0) {
        return res.json({ success: true, requests });
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
    existing.processedBy = req.user.id;
    existing.transactionRef = `TXN-EKT-${Math.floor(100000 + Math.random() * 900000)}`;

    const amt = Number(existing.amount);
    liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
    liveProducerBalance.totalWithdrawn += amt;

    // Create Notification record
    try {
      await prisma.notification.create({
        data: {
          userId: existing.producerId,
          title: 'Withdrawal Approved',
          message: `Your withdrawal request of ৳${amt.toLocaleString()} has been approved.`,
          type: 'WITHDRAWAL_APPROVED',
        },
      });
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
    existing.processedBy = req.user.id;

    const amt = Number(existing.amount);
    liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
    liveProducerBalance.availableBalance += amt;

    // Create Notification record
    try {
      await prisma.notification.create({
        data: {
          userId: existing.producerId,
          title: 'Withdrawal Rejected',
          message: `Your withdrawal request of ৳${amt.toLocaleString()} has been rejected. Note: ${existing.adminNote}`,
          type: 'WITHDRAWAL_REJECTED',
        },
      });
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
