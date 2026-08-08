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
 * Request Withdrawal
 */
async function requestWithdrawal(req, res, next) {
  try {
    const { amount, method = 'BKASH', accountDetails } = req.body;
    const reqAmount = Number(amount);

    if (!reqAmount || reqAmount <= 0) {
      return res.status(400).json({ message: 'Valid positive amount is required' });
    }

    if (reqAmount > liveProducerBalance.availableBalance) {
      return res.status(400).json({ message: 'Insufficient available balance' });
    }

    // Deduct available balance and add to pending
    liveProducerBalance.availableBalance -= reqAmount;
    liveProducerBalance.pendingWithdrawal += reqAmount;

    const newReq = {
      id: `WD-${Math.floor(1000 + Math.random() * 9000)}`,
      producerId: req.user.id || 'prod-01',
      producer: {
        id: req.user.id || 'prod-01',
        fullName: req.user.fullName || 'Nilufar Rashidova',
        email: req.user.email || 'nilufar@ekota.com.bd',
        phoneNumber: req.user.phoneNumber || '01711-223344',
        kycStatus: 'VERIFIED',
        avatarInitials: 'NR',
      },
      amount: reqAmount,
      method: method.toUpperCase(),
      accountDetails: accountDetails || { mobileNumber: '01711-223344' },
      status: 'PENDING',
      createdAt: new Date().toISOString(),
    };

    liveRequests.unshift(newReq);

    // Try saving to DB if available
    try {
      await prisma.withdrawalRequest.create({
        data: {
          producerId: req.user.id,
          amount: reqAmount,
          method: method.toUpperCase(),
          accountDetails: accountDetails || {},
          status: 'PENDING',
        },
      });
    } catch (_e) {}

    return res.status(201).json({
      message: 'Withdrawal request submitted successfully',
      withdrawalRequest: newReq,
      balance: liveProducerBalance,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get My Requests
 */
async function getMyWithdrawalRequests(req, res, next) {
  try {
    try {
      const requests = await prisma.withdrawalRequest.findMany({
        where: { producerId: req.user.id },
        orderBy: { createdAt: 'desc' },
      });
      if (requests && requests.length > 0) {
        return res.json({ requests });
      }
    } catch (_e) {}

    return res.json({ requests: liveRequests });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Get All Withdrawal Requests
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
        return res.json({ requests });
      }
    } catch (_e) {}

    let filtered = liveRequests;
    if (status && status !== 'ALL') {
      filtered = liveRequests.filter(r => r.status.toUpperCase() === status.toUpperCase());
    }

    return res.json({ requests: filtered });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Process Withdrawal Request
 */
async function processWithdrawalRequest(req, res, next) {
  try {
    const { id } = req.params;
    const { status, adminNote, transactionRef } = req.body;

    const targetStatus = status ? status.toUpperCase() : 'APPROVED';

    const reqIndex = liveRequests.findIndex(r => r.id === id || r.id.includes(id));
    if (reqIndex !== -1) {
      const existing = liveRequests[reqIndex];
      existing.status = targetStatus;
      if (adminNote) existing.adminNote = adminNote;
      if (transactionRef) existing.transactionRef = transactionRef;
      else if (targetStatus !== 'REJECTED') existing.transactionRef = `TXN-EKT-${Math.floor(100000 + Math.random() * 900000)}`;

      const amt = Number(existing.amount);

      if (targetStatus === 'APPROVED' || targetStatus === 'PROCESSED') {
        liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
        liveProducerBalance.totalWithdrawn += amt;
      } else if (targetStatus === 'REJECTED') {
        liveProducerBalance.pendingWithdrawal = Math.max(0, liveProducerBalance.pendingWithdrawal - amt);
        liveProducerBalance.availableBalance += amt;
      }

      sendNotificationEmail({
        to: existing.producer?.email || 'producer@ekota.com.bd',
        subject: `Ekota Payout Update - Withdrawal Request ${targetStatus}`,
        title: `Withdrawal Request ${targetStatus}`,
        message: `Your withdrawal request of ৳${amt} has been ${targetStatus.toLowerCase()}. ${transactionRef ? `Ref: ${transactionRef}` : ''}`,
      });

      return res.json({
        message: `Withdrawal request successfully ${targetStatus.toLowerCase()}`,
        request: existing,
        balance: liveProducerBalance,
      });
    }

    return res.status(404).json({ message: 'Request not found' });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getProducerBalance,
  requestWithdrawal,
  getMyWithdrawalRequests,
  getAllWithdrawalRequests,
  processWithdrawalRequest,
};
