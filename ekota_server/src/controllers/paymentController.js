const prisma = require('../config/prisma');
const sslcommerzService = require('../services/sslcommerzService');

/**
 * Initiate SSLCommerz payment session for Renters & Investors
 */
async function initiatePayment(req, res, next) {
  try {
    const { amount, paymentType = 'RENT', productName = 'Ekota Platform Fee' } = req.body;
    const user = req.user;

    if (!amount || isNaN(amount) || Number(amount) <= 0) {
      return res.status(400).json({ message: 'Valid amount is required' });
    }

    if (!['RENT', 'INVESTMENT'].includes(paymentType.toUpperCase())) {
      return res.status(400).json({ message: 'Invalid paymentType. Must be RENT or INVESTMENT' });
    }

    const tranId = `EKOTA-PAY-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    const payment = await prisma.payment.create({
      data: {
        userId: user.id,
        tranId: tranId,
        amount: Number(amount),
        currency: 'BDT',
        paymentType: paymentType.toUpperCase(),
        status: 'PENDING',
      },
    });

    const sessionResult = await sslcommerzService.initiateSession({
      tran_id: tranId,
      total_amount: Number(amount),
      currency: 'BDT',
      cus_name: user.fullName || 'Ekota Member',
      cus_email: user.email,
      cus_phone: user.phoneNumber || '01700000000',
      product_name: productName,
      product_category: paymentType,
    });

    if (!sessionResult.success && !sessionResult.gatewayPageUrl) {
      await prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'FAILED' },
      });
      return res.status(500).json({
        message: 'Failed to initialize SSLCommerz gateway session',
        error: sessionResult.error,
      });
    }

    await prisma.payment.update({
      where: { id: payment.id },
      data: { gatewayPageUrl: sessionResult.gatewayPageUrl },
    });

    return res.status(201).json({
      message: 'Payment session initiated successfully',
      paymentId: payment.id,
      tranId: tranId,
      gatewayPageUrl: sessionResult.gatewayPageUrl,
      amount: Number(amount),
      currency: 'BDT',
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Success Callback
 */
async function handleSuccess(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id, val_id, amount, card_type, bank_tran_id } = payload;

    const payment = await prisma.payment.findUnique({
      where: { tranId: tran_id },
      include: { user: true },
    });

    if (!payment) {
      return res.status(404).send('<h3>Payment transaction not found</h3>');
    }

    let valResult = { isValid: true };
    if (val_id) {
      valResult = await sslcommerzService.validateTransaction(val_id);
    }

    if (valResult.isValid) {
      const updatedPayment = await prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: 'VALIDATED',
          valId: val_id || `val_${Date.now()}`,
          cardType: card_type || valResult.cardType || 'ONLINE',
          bankTranId: bank_tran_id || valResult.bankTranId || `bank_${Date.now()}`,
          metadata: payload,
        },
      });

      // Create Notification for user
      await prisma.notification.create({
        data: {
          userId: payment.userId,
          title: 'Payment Successful',
          message: `Your payment of ৳${payment.amount} (${payment.paymentType}) with Tran ID ${payment.tranId} was completed successfully.`,
          type: 'PAYMENT_SUCCESS',
          metadata: { paymentId: payment.id, tranId: payment.tranId },
        },
      });

      if (req.headers.accept && req.headers.accept.includes('application/json')) {
        return res.json({ message: 'Payment validated successfully', payment: updatedPayment });
      }

      return res.send(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Payment Successful - Ekota</title>
          <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f3f4f6; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); text-align: center; max-width: 450px; }
            .icon { font-size: 50px; color: #10b981; margin-bottom: 16px; }
            h2 { color: #111827; margin-bottom: 8px; }
            p { color: #6b7280; margin: 6px 0; }
            .badge { display: inline-block; background: #ecfdf5; color: #047857; font-weight: bold; padding: 6px 16px; border-radius: 20px; margin-top: 15px; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">✓</div>
            <h2>Payment Successful!</h2>
            <p>Transaction ID: <strong>${payment.tranId}</strong></p>
            <p>Amount: <strong>৳${payment.amount} BDT</strong></p>
            <p>Type: <strong>${payment.paymentType}</strong></p>
            <div class="badge">Status: VALIDATED</div>
          </div>
        </body>
        </html>
      `);
    } else {
      await prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'FAILED', metadata: payload },
      });
      return res.status(400).send('<h3>Payment validation failed</h3>');
    }
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Failure Callback
 */
async function handleFail(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    if (tran_id) {
      const payment = await prisma.payment.findUnique({ where: { tranId: tran_id } });
      if (payment) {
        await prisma.payment.update({
          where: { id: payment.id },
          data: { status: 'FAILED', metadata: payload },
        });

        await prisma.notification.create({
          data: {
            userId: payment.userId,
            title: 'Payment Failed',
            message: `Your payment of ৳${payment.amount} (${payment.paymentType}) with Tran ID ${payment.tranId} failed.`,
            type: 'PAYMENT_FAILED',
            metadata: { paymentId: payment.id },
          },
        });
      }
    }

    if (req.headers.accept && req.headers.accept.includes('application/json')) {
      return res.status(400).json({ message: 'Payment failed' });
    }

    return res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Payment Failed - Ekota</title>
        <style>
          body { font-family: sans-serif; background: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; }
          .icon { font-size: 50px; color: #ef4444; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">✕</div>
          <h2>Payment Failed</h2>
          <p>The transaction could not be processed.</p>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Cancellation Callback
 */
async function handleCancel(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    if (tran_id) {
      const payment = await prisma.payment.findUnique({ where: { tranId: tran_id } });
      if (payment) {
        await prisma.payment.update({
          where: { id: payment.id },
          data: { status: 'CANCELLED', metadata: payload },
        });
      }
    }

    if (req.headers.accept && req.headers.accept.includes('application/json')) {
      return res.json({ message: 'Payment cancelled' });
    }

    return res.send(`
      <!DOCTYPE html>
      <html>
      <head><title>Payment Cancelled</title></head>
      <body style="font-family:sans-serif; text-align:center; padding-top:100px;">
        <h2>Payment Cancelled</h2>
        <p>You have cancelled the payment process.</p>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle IPN (Instant Payment Notification)
 */
async function handleIPN(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id, val_id, status } = payload;

    if (!tran_id) return res.status(400).json({ message: 'Missing tran_id' });

    const payment = await prisma.payment.findUnique({ where: { tranId: tran_id } });
    if (!payment) return res.status(404).json({ message: 'Payment not found' });

    if (status === 'VALID' || status === 'VALIDATED') {
      await prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'VALIDATED', valId: val_id || payment.valId, metadata: payload },
      });
    }

    return res.json({ message: 'IPN processed' });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get Payment History for logged in user
 */
async function getUserPayments(req, res, next) {
  try {
    const payments = await prisma.payment.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ payments });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get payment details by ID
 */
async function getPaymentById(req, res, next) {
  try {
    const payment = await prisma.payment.findFirst({
      where: { id: req.params.id, userId: req.user.id },
    });
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
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ message: 'Access denied. Admin required.' });
    }

    const payments = await prisma.payment.findMany({
      include: {
        user: {
          select: { id: true, fullName: true, email: true, role: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ payments });
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
};
