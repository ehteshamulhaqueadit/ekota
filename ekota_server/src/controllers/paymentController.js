const prisma = require('../config/prisma');
const sslcommerzService = require('../services/sslcommerzService');

// Live in-memory store for dev / fallback payments
let livePayments = [
  {
    id: 'pay_demo_01',
    userId: '00000000-0000-0000-0000-000000000001',
    tranId: 'EKOTA-PAY-1786331900-101',
    amount: 15000,
    currency: 'BDT',
    paymentType: 'RENT',
    status: 'PENDING',
    cardType: 'SSLCommerz Gateway',
    createdAt: new Date().toISOString(),
    user: { fullName: 'Renter Member', email: 'renter@ekota.com', role: 'RENTER' },
  },
  {
    id: 'pay_demo_02',
    userId: '00000000-0000-0000-0000-000000000002',
    tranId: 'EKOTA-PAY-1786331950-202',
    amount: 50000,
    currency: 'BDT',
    paymentType: 'INVESTMENT',
    status: 'PENDING',
    cardType: 'SSLCommerz Gateway',
    createdAt: new Date(Date.now() - 3600000 * 2).toISOString(),
    user: { fullName: 'Investor Member', email: 'investor@ekota.com', role: 'INVESTOR' },
  },
];

/**
 * Initiate SSLCommerz payment session for Renters & Investors
 */
async function initiatePayment(req, res, next) {
  try {
    const { amount, paymentType = 'RENT', productName = 'Ekota Platform Fee' } = req.body;
    const user = req.user || { id: '00000000-0000-0000-0000-000000000001', fullName: 'Renter Member', email: 'renter@ekota.com' };

    if (!amount || isNaN(amount) || Number(amount) <= 0) {
      return res.status(400).json({ message: 'Valid amount is required' });
    }

    if (!['RENT', 'INVESTMENT'].includes(paymentType.toUpperCase())) {
      return res.status(400).json({ message: 'Invalid paymentType. Must be RENT or INVESTMENT' });
    }

    const tranId = `EKOTA-PAY-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    let newPayment = {
      id: `pay_${Date.now()}`,
      userId: user.id,
      tranId: tranId,
      amount: Number(amount),
      currency: 'BDT',
      paymentType: paymentType.toUpperCase(),
      status: 'PENDING',
      cardType: 'SSLCommerz Gateway',
      createdAt: new Date().toISOString(),
      user: { fullName: user.fullName || 'Renter Member', email: user.email || 'renter@ekota.com', role: user.role || 'RENTER' },
    };

    try {
      const dbPay = await prisma.payment.create({
        data: {
          userId: user.id,
          tranId: tranId,
          amount: Number(amount),
          currency: 'BDT',
          paymentType: paymentType.toUpperCase(),
          status: 'PENDING',
        },
      });
      newPayment.id = dbPay.id;
    } catch (_e) {}

    livePayments.unshift(newPayment);

    const sessionResult = await sslcommerzService.initiateSession({
      tran_id: tranId,
      total_amount: Number(amount),
      currency: 'BDT',
      cus_name: user.fullName || 'Ekota Member',
      cus_email: user.email || 'customer@ekota.com',
      cus_phone: user.phoneNumber || '01700000000',
      product_name: productName,
      product_category: paymentType,
    });

    return res.status(201).json({
      message: 'Payment session initiated successfully. Status is PENDING admin verification.',
      paymentId: newPayment.id,
      tranId: newPayment.tranId,
      status: 'PENDING',
      gatewayPageUrl: sessionResult.gatewayPageUrl || `https://sandbox.sslcommerz.com/gwprocess/v4/simulators/index.php?tran_id=${tranId}`,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Success Callback (Keeps status PENDING for Admin Verification)
 */
async function handleSuccess(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    const payIndex = livePayments.findIndex(p => p.tranId === tran_id);
    if (payIndex !== -1) {
      livePayments[payIndex].metadata = payload;
    }

    if (req.headers.accept && req.headers.accept.includes('application/json')) {
      return res.json({ message: 'Payment submitted successfully. Pending Admin verification.', tranId: tran_id, status: 'PENDING' });
    }

    return res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Payment Submitted - Pending Admin Verification</title>
        <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f3f4f6; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); text-align: center; max-width: 450px; }
          .icon { font-size: 50px; color: #d97706; margin-bottom: 16px; }
          h2 { color: #111827; margin-bottom: 8px; }
          p { color: #6b7280; margin: 6px 0; }
          .badge { display: inline-block; background: #fef3c7; color: #d97706; font-weight: bold; padding: 6px 16px; border-radius: 20px; margin-top: 15px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">⏳</div>
          <h2>Payment Submitted!</h2>
          <p>Transaction ID: <strong>${tran_id || 'EKOTA-PAY-01'}</strong></p>
          <p>Status: <strong>PENDING ADMIN VERIFICATION</strong></p>
          <div class="badge">Awaiting Admin Validation</div>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

async function handleFail(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;
    if (tran_id) {
      const payIndex = livePayments.findIndex(p => p.tranId === tran_id);
      if (payIndex !== -1) livePayments[payIndex].status = 'FAILED';
    }
    return res.status(400).send('<h3>Payment Failed</h3>');
  } catch (error) {
    return next(error);
  }
}

async function handleCancel(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;
    if (tran_id) {
      const payIndex = livePayments.findIndex(p => p.tranId === tran_id);
      if (payIndex !== -1) livePayments[payIndex].status = 'CANCELLED';
    }
    return res.send('<h3>Payment Cancelled</h3>');
  } catch (error) {
    return next(error);
  }
}

async function handleIPN(req, res) {
  return res.json({ message: 'IPN received' });
}

/**
 * Get Payment History for logged in user
 */
async function getUserPayments(req, res, next) {
  try {
    let dbPayments = [];
    try {
      dbPayments = await prisma.payment.findMany({
        where: { userId: req.user?.id },
        orderBy: { createdAt: 'desc' },
      });
    } catch (_e) {}

    const map = new Map();
    for (const p of livePayments) {
      if (!req.user?.id || p.userId === req.user.id || p.user?.email?.toLowerCase() === req.user?.email?.toLowerCase()) {
        map.set(p.tranId || p.id, p);
      }
    }
    for (const dbP of dbPayments) {
      map.set(dbP.tranId || dbP.id, {
        id: dbP.id,
        tranId: dbP.tranId,
        amount: dbP.amount,
        currency: dbP.currency || 'BDT',
        paymentType: dbP.paymentType,
        status: dbP.status,
        cardType: dbP.cardType || 'ONLINE',
        createdAt: dbP.createdAt,
        user: dbP.user || { fullName: 'Renter Member', email: 'renter@ekota.com', role: 'RENTER' },
      });
    }

    const combined = Array.from(map.values());
    return res.json({ payments: combined.length > 0 ? combined : livePayments });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get payment details by ID
 */
async function getPaymentById(req, res, next) {
  try {
    const payment = livePayments.find(p => p.id === req.params.id || p.tranId === req.params.id);
    if (!payment) return res.status(404).json({ message: 'Payment record not found' });
    return res.json({ payment });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Get all payments
 */
async function getAllPayments(req, res, next) {
  try {
    let dbPayments = [];
    try {
      dbPayments = await prisma.payment.findMany({
        include: {
          user: {
            select: { id: true, fullName: true, email: true, role: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
    } catch (_e) {}

    const map = new Map();
    for (const p of livePayments) {
      map.set(p.tranId || p.id, p);
    }
    for (const dbP of dbPayments) {
      map.set(dbP.tranId || dbP.id, {
        id: dbP.id,
        tranId: dbP.tranId,
        amount: dbP.amount,
        currency: dbP.currency || 'BDT',
        paymentType: dbP.paymentType,
        status: dbP.status,
        cardType: dbP.cardType || 'ONLINE',
        createdAt: dbP.createdAt,
        user: dbP.user || { fullName: 'Customer', email: 'user@ekota.com', role: 'RENTER' },
      });
    }

    const combined = Array.from(map.values());
    return res.json({ payments: combined });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Validate Payment (PATCH /api/payments/:id/validate or approve)
 */
async function adminValidatePayment(req, res, next) {
  try {
    const { id } = req.params;
    let target = null;

    // 1. Update in DB if matched
    try {
      const dbMatch = await prisma.payment.findFirst({
        where: { OR: [{ id: id }, { tranId: id }] }
      });
      if (dbMatch) {
        await prisma.payment.update({
          where: { id: dbMatch.id },
          data: { status: 'VALIDATED' },
        });
        target = { ...dbMatch, status: 'VALIDATED' };
      }
    } catch (_e) {}

    // 2. Update in memory livePayments if matched
    let payIndex = livePayments.findIndex(p => p.id === id || p.tranId === id);
    if (payIndex === -1 && id) {
      payIndex = livePayments.findIndex(p => p.id.includes(id) || p.tranId.includes(id) || id.includes(p.id) || id.includes(p.tranId));
    }

    if (payIndex !== -1) {
      livePayments[payIndex].status = 'VALIDATED';
      livePayments[payIndex].validatedAt = new Date().toISOString();
      if (!target) target = livePayments[payIndex];
    }

    if (target) {
      try {
        await prisma.notification.create({
          data: {
            userId: target.userId || '00000000-0000-0000-0000-000000000001',
            title: 'Payment Validated',
            message: `Your payment of ৳${target.amount} (${target.paymentType}) with Tran ID ${target.tranId} has been verified and validated by Admin.`,
            type: 'PAYMENT_SUCCESS',
          },
        });
      } catch (_e) {}

      return res.json({
        success: true,
        message: `Payment ${target.tranId || id} validated successfully by Admin`,
        payment: target,
      });
    }

    return res.status(404).json({ success: false, message: 'Payment record not found' });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Reject Payment (PATCH /api/payments/:id/reject)
 */
async function adminRejectPayment(req, res, next) {
  try {
    const { id } = req.params;
    const { note } = req.body || {};
    let target = null;

    // 1. Update in DB if matched
    try {
      const dbMatch = await prisma.payment.findFirst({
        where: { OR: [{ id: id }, { tranId: id }] }
      });
      if (dbMatch) {
        await prisma.payment.update({
          where: { id: dbMatch.id },
          data: { status: 'FAILED' },
        });
        target = { ...dbMatch, status: 'FAILED', adminNote: note || 'Rejected by administrator' };
      }
    } catch (_e) {}

    // 2. Update in memory livePayments if matched
    let payIndex = livePayments.findIndex(p => p.id === id || p.tranId === id);
    if (payIndex === -1 && id) {
      payIndex = livePayments.findIndex(p => p.id.includes(id) || p.tranId.includes(id) || id.includes(p.id) || id.includes(p.tranId));
    }

    if (payIndex !== -1) {
      livePayments[payIndex].status = 'FAILED';
      livePayments[payIndex].adminNote = note || 'Rejected by administrator';
      if (!target) target = livePayments[payIndex];
    }

    if (target) {
      try {
        await prisma.notification.create({
          data: {
            userId: target.userId || '00000000-0000-0000-0000-000000000001',
            title: 'Payment Rejected',
            message: `Your payment of ৳${target.amount} (${target.paymentType}) with Tran ID ${target.tranId} was rejected by Admin. Note: ${target.adminNote || 'Rejected by administrator'}`,
            type: 'PAYMENT_FAILED',
          },
        });
      } catch (_e) {}

      return res.json({
        success: true,
        message: `Payment ${target.tranId || id} rejected by Admin`,
        payment: target,
      });
    }

    return res.status(404).json({ success: false, message: 'Payment record not found' });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  initiatePayment,
  handleSuccess,
  handleFail,
  handleCancel,
  handleIPN,
  getUserPayments,
  getPaymentById,
  getAllPayments,
  adminValidatePayment,
  adminRejectPayment,
};
