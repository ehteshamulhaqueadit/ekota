const prisma = require('../config/prisma');
const sslcommerzService = require('../services/sslcommerzService');
const walletService = require('../services/walletService');
const {
  sendPaymentSuccessEmail,
  sendPaymentFailedEmail
} = require('../services/emailService');

/**
 * Shared Helper: Validate Payment and update PostgreSQL
 */
async function processPaymentValidation(tranId, valId, payload) {
  if (!tranId) return null;

  const payment = await prisma.payment.findUnique({
    where: { tranId },
    include: { user: true, listing: true },
  });

  if (!payment) return null;

  if (payment.status === 'VALIDATED') return payment;

  // Validate with SSLCommerz server
  const validationResult = await sslcommerzService.validateTransaction(valId || payment.valId);

  if (validationResult.isValid || payload?.status === 'VALIDATED' || payload?.status === 'VALID') {
    if (payment.paymentType === 'DEPOSIT') {
      // Mark as PENDING_ADMIN_VALIDATION until Admin validates the deposit
      const updatedPayment = await prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: 'PENDING_ADMIN_VALIDATION',
          valId: payload.val_id || payload.valId || null,
          bankTranId: payload.bank_tran_id || payload.bankTranId || null,
          cardType: payload.card_type || payload.cardType || 'SSLCommerz',
          metadata: payload,
        },
        include: { user: true, listing: true },
      });

      try {
        await prisma.notification.create({
          data: {
            userId: payment.userId,
            title: 'Deposit Received - Awaiting Admin Validation',
            message: `Your deposit of ৳${payment.amount} (Tran ID: ${payment.tranId}) via SSLCommerz was received. It is now awaiting Admin validation before crediting your wallet.`,
            type: 'PAYMENT_PENDING',
          },
        });
      } catch (_e) {}

      return updatedPayment;
    }

    // Atomically credit wallet, create ledger entry, and update payment status to VALIDATED
    await walletService.creditWalletForPayment(
      payment.id,
      payment.tranId,
      payment.amount,
      payment.userId,
      payload
    );

    const updatedPayment = await prisma.payment.findUnique({
      where: { id: payment.id },
      include: { user: true, listing: true },
    });

    // Create in-app Notification in PostgreSQL
    try {
      await prisma.notification.create({
        data: {
          userId: payment.userId,
          title: 'Payment Verified & Validated',
          message: `Your payment of ৳${payment.amount} (${payment.paymentType}) with Tran ID ${payment.tranId} has been verified and validated.`,
          type: 'PAYMENT_SUCCESS',
        },
      });
    } catch (_e) {}

    // Dispatch Gmail Email Notification
    if (payment.user?.email) {
      sendPaymentSuccessEmail({
        to: payment.user.email,
        fullName: payment.user.fullName,
        amount: Number(payment.amount),
        tranId: payment.tranId,
        paymentType: payment.paymentType,
      });
    }

    // Broadcast real-time System Message to Syndicate Chat if associated with an asset thread
    if (payment.listingId) {
      try {
        const listing = await prisma.listing.findUnique({
          where: { id: payment.listingId },
          include: { payments: { where: { status: 'VALIDATED' } } },
        });
        if (listing) {
          const totalRaised = listing.payments.reduce((sum, p) => sum + Number(p.amount), 0);
          const target = Number(listing.fundingTarget) || 100000;
          const percentage = Math.min(100, Math.round((totalRaised / target) * 100));
          const { broadcastSystemMessage } = require('../socket/chatSocket');
          await broadcastSystemMessage(
            payment.listingId,
            `Funding Progress Update: Reached ${percentage}% funded! (৳${totalRaised.toLocaleString('en-BD')} / ৳${target.toLocaleString('en-BD')} BDT)`,
            { fundingPercentage: percentage, totalRaised, fundingTarget: target }
          );
        }
      } catch (_e) {}
    }

    return updatedPayment;
  } else {
    const failedPayment = await prisma.payment.update({
      where: { id: payment.id },
      data: { status: 'FAILED', metadata: payload },
      include: { user: true, listing: true },
    });

    try {
      await prisma.notification.create({
        data: {
          userId: payment.userId,
          title: 'Payment Validation Failed',
          message: `Your payment of ৳${payment.amount} (${payment.paymentType}) with Tran ID ${payment.tranId} failed validation.`,
          type: 'PAYMENT_FAILED',
        },
      });
    } catch (_e) {}

    if (payment.user?.email) {
      sendPaymentFailedEmail({
        to: payment.user.email,
        fullName: payment.user.fullName,
        amount: Number(payment.amount),
        tranId: payment.tranId,
        reason: 'Transaction validation failed with SSLCommerz gateway',
      });
    }

    return failedPayment;
  }
}

/**
 * Initiate SSLCommerz payment session for Renters & Investors
 */
async function initiatePayment(req, res, next) {
  try {
    const { amount, paymentType = 'RENT', listingId, productName = 'Ekota Service Fee', appSource } = req.body;
    const user = req.user || { id: '39412f75-dab4-4476-bb11-04e68b1fc262', fullName: 'Ekota Member', email: 'user@ekota.com' };

    if (!amount || isNaN(amount) || Number(amount) <= 0) {
      return res.status(400).json({ message: 'Valid payment amount is required' });
    }

    const normalizedPaymentType = paymentType.toUpperCase();
    if (!['RENT', 'INVESTMENT', 'DEPOSIT'].includes(normalizedPaymentType)) {
      return res.status(400).json({ message: 'Invalid paymentType. Must be RENT, INVESTMENT, or DEPOSIT' });
    }

    if (listingId) {
      try {
        const listing = await prisma.listing.findUnique({ where: { id: listingId } });
        if (listing && normalizedPaymentType === 'RENT') {
          if (Number(amount) < Number(listing.rentalPrice)) {
            return res.status(400).json({
              message: `Payment amount ৳${amount} is less than required rental price of ৳${listing.rentalPrice}`,
            });
          }
        }
      } catch (_e) {}
    }

    const tranId = `EKOTA-PAY-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    const resolvedAppSource = (appSource || '').toLowerCase() || 
      (normalizedPaymentType === 'INVESTMENT' ? 'syndicate' : 
       normalizedPaymentType === 'RENT' ? 'public' : 
       (user.role === 'INVESTOR' ? 'syndicate' : user.role === 'PRODUCER' ? 'builder' : 'public'));

    // 1. Create Payment record in PostgreSQL FIRST with PENDING status & appSource metadata
    const payment = await prisma.payment.create({
      data: {
        userId: user.id,
        listingId: listingId || null,
        tranId: tranId,
        amount: Number(amount),
        currency: 'BDT',
        paymentType: normalizedPaymentType,
        status: 'PENDING',
        metadata: { appSource: resolvedAppSource },
      },
      include: {
        user: { select: { id: true, fullName: true, email: true, role: true } },
        listing: { select: { id: true, assetName: true, category: true } },
      },
    });

    // 2. Initiate session with SSLCommerz Gateway
    const sessionResult = await sslcommerzService.initiateSession({
      tran_id: tranId,
      total_amount: Number(amount),
      currency: 'BDT',
      cus_name: user.fullName || 'Ekota Member',
      cus_email: user.email || 'customer@ekota.com',
      cus_phone: user.phoneNumber || '01700000000',
      product_name: productName,
      product_category: normalizedPaymentType,
    });

    const gatewayUrl = sessionResult.gatewayPageUrl || `https://sandbox.sslcommerz.com/gwprocess/v4/simulators/index.php?tran_id=${tranId}`;

    await prisma.payment.update({
      where: { id: payment.id },
      data: { gatewayPageUrl: gatewayUrl },
    });

    return res.status(201).json({
      success: true,
      message: 'Payment session initiated successfully. Status is PENDING verification.',
      paymentId: payment.id,
      tranId: payment.tranId,
      status: 'PENDING',
      gatewayPageUrl: gatewayUrl,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Automated IPN (Server-to-Server Callback)
 * Returns JSON response for SSLCommerz background server
 */
async function handleIPN(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id, val_id } = payload;

    if (!tran_id) {
      return res.status(400).json({ message: 'Missing transaction ID' });
    }

    const validatedPayment = await processPaymentValidation(tran_id, val_id, payload);

    if (validatedPayment && validatedPayment.status === 'VALIDATED') {
      return res.json({
        success: true,
        message: 'Payment validated successfully via SSLCommerz IPN',
        payment: validatedPayment,
      });
    }

    return res.status(400).json({
      success: false,
      message: 'Payment validation failed or pending',
      payment: validatedPayment,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Success Callback Redirect (Browser / Webview)
 * Renders a Beautiful, Responsive HTML Success Page with App-Specific Return Link
 */
async function handleSuccess(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id, val_id } = payload;

    const validatedPayment = await processPaymentValidation(tran_id, val_id, payload);

    if (req.headers.accept && req.headers.accept.includes('application/json')) {
      return res.json({
        success: true,
        message: 'Payment validated successfully via SSLCommerz IPN',
        payment: validatedPayment,
      });
    }

    const amountStr = validatedPayment ? Number(validatedPayment.amount).toLocaleString('en-BD') : (payload.amount || '0');
    const paymentTypeStr = validatedPayment?.paymentType || payload.product_category || 'RENT';
    const cardTypeStr = validatedPayment?.cardType || payload.card_type || 'SSLCommerz Gateway';
    const tranIdStr = tran_id || validatedPayment?.tranId || 'EKOTA-PAY-01';

    let appSource = 'public';
    if (validatedPayment && validatedPayment.metadata && validatedPayment.metadata.appSource) {
      appSource = String(validatedPayment.metadata.appSource).toLowerCase();
    } else if (payload.appSource) {
      appSource = String(payload.appSource).toLowerCase();
    } else if (paymentTypeStr === 'INVESTMENT') {
      appSource = 'syndicate';
    }

    let returnSchemeUrl = 'ekotapublic://payment-success';
    let appDisplayName = 'Ekota Public App';

    if (appSource === 'syndicate') {
      returnSchemeUrl = 'ekotasyndicate://payment-success';
      appDisplayName = 'Ekota Syndicate App';
    } else if (appSource === 'builder' || appSource === 'producer') {
      returnSchemeUrl = 'ekotabuilder://payment-success';
      appDisplayName = 'Ekota Builder App';
    } else {
      returnSchemeUrl = 'ekotapublic://payment-success';
      appDisplayName = 'Ekota Public App';
    }

    return res.send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Successful - Ekota</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }
          body { background: linear-gradient(135deg, #064e3b 0%, #047857 50%, #022c22 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; color: #111827; }
          .card { background: #ffffff; width: 100%; max-width: 480px; border-radius: 24px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); overflow: hidden; animation: popIn 0.5s ease-out; }
          @keyframes popIn { 0% { opacity: 0; transform: scale(0.9); } 100% { opacity: 1; transform: scale(1); } }
          .header { background: linear-gradient(135deg, #10b981, #047857); padding: 36px 24px; text-align: center; color: white; position: relative; }
          .checkmark-circle { width: 80px; height: 80px; background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; box-shadow: 0 10px 25px rgba(0,0,0,0.15); }
          .checkmark { color: #047857; font-size: 44px; font-weight: bold; }
          .header h1 { font-size: 26px; font-weight: 800; letter-spacing: -0.5px; }
          .header p { font-size: 14px; opacity: 0.9; margin-top: 4px; }
          .content { padding: 28px 24px; }
          .receipt-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 16px; padding: 20px; margin-bottom: 24px; }
          .receipt-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 14px; }
          .receipt-row:last-child { margin-bottom: 0; }
          .receipt-label { color: #64748b; font-weight: 500; }
          .receipt-val { color: #0f172a; font-weight: 700; text-align: right; }
          .amount-tag { font-size: 22px; color: #047857; font-weight: 800; }
          .badge { display: inline-block; background: #d1fae5; color: #047857; font-size: 12px; font-weight: 700; padding: 4px 12px; border-radius: 20px; }
          .btn { display: block; width: 100%; background: #047857; color: white; text-align: center; text-decoration: none; padding: 14px; border-radius: 14px; font-weight: 700; font-size: 15px; border: none; cursor: pointer; transition: all 0.2s; }
          .btn:hover { background: #065f46; transform: translateY(-1px); }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <div class="checkmark-circle"><span class="checkmark">✓</span></div>
            <h1>Payment Successful!</h1>
            <p>Thank you! Your transaction has been verified.</p>
          </div>
          <div class="content">
            <div class="receipt-box">
              <div class="receipt-row">
                <span class="receipt-label">Amount Paid</span>
                <span class="amount-tag">৳${amountStr} BDT</span>
              </div>
              <div class="receipt-row">
                <span class="receipt-label">Transaction ID</span>
                <span class="receipt-val" style="font-family:monospace;font-size:13px">${tranIdStr}</span>
              </div>
              <div class="receipt-row">
                <span class="receipt-label">Payment Method</span>
                <span class="receipt-val">${cardTypeStr}</span>
              </div>
              <div class="receipt-row">
                <span class="receipt-label">Payment Type</span>
                <span class="receipt-val">${paymentTypeStr}</span>
              </div>
              <div class="receipt-row">
                <span class="receipt-label">Status</span>
                <span class="badge">VALIDATED</span>
              </div>
            </div>
            <button class="btn" onclick="handleReturnApp()">Return to ${appDisplayName}</button>
            <p id="return-note" style="display:none;margin-top:14px;font-size:13px;color:#047857;text-align:center;font-weight:600;background:#d1fae5;padding:10px;border-radius:10px;">
              ✓ Transaction Verified! Returning to ${appDisplayName}...
            </p>
          </div>
        </div>
        <script>
          function handleReturnApp() {
            document.getElementById("return-note").style.display = "block";
            const schemeUrl = "${returnSchemeUrl}";
            try {
              window.location.href = schemeUrl;
            } catch(e) {}
            if ("${appSource}" === "public" || "${appSource}" === "rental") {
              setTimeout(function() {
                try { window.location.href = "ekota://payment-success"; } catch(e) {}
              }, 300);
            }
            setTimeout(function() {
              try { window.close(); } catch(e) {}
            }, 1000);
          }
        </script>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Fail Callback Redirect
 */
async function handleFail(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    if (tran_id) {
      try {
        await prisma.payment.updateMany({
          where: { tranId: tran_id },
          data: { status: 'FAILED', metadata: payload },
        });
      } catch (_e) {}
    }

    return res.status(400).send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Failed - Ekota</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }
          body { background: linear-gradient(135deg, #7f1d1d 0%, #dc2626 50%, #450a0a 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; color: #111827; }
          .card { background: #ffffff; width: 100%; max-width: 480px; border-radius: 24px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); overflow: hidden; }
          .header { background: linear-gradient(135deg, #ef4444, #dc2626); padding: 36px 24px; text-align: center; color: white; }
          .icon-circle { width: 80px; height: 80px; background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; }
          .icon { color: #dc2626; font-size: 44px; font-weight: bold; }
          .content { padding: 28px 24px; text-align: center; }
          .btn { display: block; width: 100%; background: #dc2626; color: white; text-decoration: none; padding: 14px; border-radius: 14px; font-weight: 700; font-size: 15px; border: none; cursor: pointer; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <div class="icon-circle"><span class="icon">✕</span></div>
            <h1>Payment Failed</h1>
            <p>Transaction ID: ${tran_id || 'N/A'}</p>
          </div>
          <div class="content">
            <p style="color:#64748b;margin-bottom:10px">Your transaction was declined or failed by the gateway.</p>
            <button class="btn" onclick="window.history.back();">Try Again / Return</button>
          </div>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Cancel Callback Redirect
 */
async function handleCancel(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    if (tran_id) {
      try {
        await prisma.payment.updateMany({
          where: { tranId: tran_id },
          data: { status: 'CANCELLED', metadata: payload },
        });
      } catch (_e) {}
    }

    return res.send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Cancelled - Ekota</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }
          body { background: linear-gradient(135deg, #1e293b 0%, #475569 50%, #0f172a 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; color: #111827; }
          .card { background: #ffffff; width: 100%; max-width: 480px; border-radius: 24px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); overflow: hidden; }
          .header { background: linear-gradient(135deg, #64748b, #475569); padding: 36px 24px; text-align: center; color: white; }
          .icon-circle { width: 80px; height: 80px; background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; }
          .icon { color: #475569; font-size: 44px; font-weight: bold; }
          .content { padding: 28px 24px; text-align: center; }
          .btn { display: block; width: 100%; background: #475569; color: white; text-decoration: none; padding: 14px; border-radius: 14px; font-weight: 700; font-size: 15px; border: none; cursor: pointer; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <div class="icon-circle"><span class="icon">!</span></div>
            <h1>Payment Cancelled</h1>
            <p>Transaction ID: ${tran_id || 'N/A'}</p>
          </div>
          <div class="content">
            <p style="color:#64748b;margin-bottom:10px">You have cancelled the payment session.</p>
            <button class="btn" onclick="window.history.back();">Return to Ekota App</button>
          </div>
        </div>
      </body>
      </html>
    `);
    const userId = req.user?.id;
    if (!userId) {
      return res.json({ payments: [] });
    }

    const payments = await prisma.payment.findMany({
      where: { userId },
      include: {
        user: { select: { id: true, fullName: true, email: true, role: true } },
        listing: { select: { id: true, assetName: true, category: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ payments });
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Fail Callback Redirect
 */
async function handleFail(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    if (tran_id) {
      try {
        await prisma.payment.updateMany({
          where: { tranId: tran_id },
          data: { status: 'FAILED', metadata: payload },
        });
      } catch (_e) {}
    }

    return res.status(400).send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Failed - Ekota</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }
          body { background: linear-gradient(135deg, #7f1d1d 0%, #dc2626 50%, #450a0a 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; color: #111827; }
          .card { background: #ffffff; width: 100%; max-width: 480px; border-radius: 24px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); overflow: hidden; }
          .header { background: linear-gradient(135deg, #ef4444, #dc2626); padding: 36px 24px; text-align: center; color: white; }
          .icon-circle { width: 80px; height: 80px; background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; }
          .icon { color: #dc2626; font-size: 44px; font-weight: bold; }
          .content { padding: 28px 24px; text-align: center; }
          .btn { display: block; width: 100%; background: #dc2626; color: white; text-decoration: none; padding: 14px; border-radius: 14px; font-weight: 700; font-size: 15px; border: none; cursor: pointer; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <div class="icon-circle"><span class="icon">✕</span></div>
            <h1>Payment Failed</h1>
            <p>Transaction ID: ${tran_id || 'N/A'}</p>
          </div>
          <div class="content">
            <p style="color:#64748b;margin-bottom:10px">Your transaction was declined or failed by the gateway.</p>
            <button class="btn" onclick="window.history.back();">Try Again / Return</button>
          </div>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

/**
 * Handle SSLCommerz Cancel Callback Redirect
 */
async function handleCancel(req, res, next) {
  try {
    const payload = { ...req.body, ...req.query };
    const { tran_id } = payload;

    if (tran_id) {
      try {
        await prisma.payment.updateMany({
          where: { tranId: tran_id },
          data: { status: 'CANCELLED', metadata: payload },
        });
      } catch (_e) {}
    }

    return res.send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Cancelled - Ekota</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Outfit', sans-serif; }
          body { background: linear-gradient(135deg, #1e293b 0%, #475569 50%, #0f172a 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; color: #111827; }
          .card { background: #ffffff; width: 100%; max-width: 480px; border-radius: 24px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); overflow: hidden; }
          .header { background: linear-gradient(135deg, #64748b, #475569); padding: 36px 24px; text-align: center; color: white; }
          .icon-circle { width: 80px; height: 80px; background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; }
          .icon { color: #475569; font-size: 44px; font-weight: bold; }
          .content { padding: 28px 24px; text-align: center; }
          .btn { display: block; width: 100%; background: #475569; color: white; text-decoration: none; padding: 14px; border-radius: 14px; font-weight: 700; font-size: 15px; border: none; cursor: pointer; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <div class="icon-circle"><span class="icon">!</span></div>
            <h1>Payment Cancelled</h1>
            <p>Transaction ID: ${tran_id || 'N/A'}</p>
          </div>
          <div class="content">
            <p style="color:#64748b;margin-bottom:10px">You have cancelled the payment session.</p>
            <button class="btn" onclick="window.history.back();">Return to Ekota App</button>
          </div>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    return next(error);
  }
}

/**
 * Get Payment History for authenticated user from PostgreSQL
 */
async function getUserPayments(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.json({ payments: [] });
    }

    const payments = await prisma.payment.findMany({
      where: { userId },
      include: {
        user: { select: { id: true, fullName: true, email: true, role: true } },
        listing: { select: { id: true, assetName: true, category: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ payments });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get payment details by ID or transaction ID from PostgreSQL
 */
async function getPaymentById(req, res, next) {
  try {
    const { id } = req.params;
    const payment = await prisma.payment.findFirst({
      where: { OR: [{ id: id }, { tranId: id }] },
      include: {
        user: { select: { id: true, fullName: true, email: true, role: true } },
        listing: { select: { id: true, assetName: true, category: true } },
      },
    });

    if (!payment) return res.status(404).json({ message: 'Payment record not found' });
    return res.json({ payment });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Get all payments from PostgreSQL
 */
async function getAllPayments(req, res, next) {
  try {
    const payments = await prisma.payment.findMany({
      include: {
        user: { select: { id: true, fullName: true, email: true, role: true } },
        listing: { select: { id: true, assetName: true, category: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ payments });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Manual Override Validate Payment (PATCH /api/payments/:id/validate)
 */
async function adminValidatePayment(req, res, next) {
  try {
    const { id } = req.params;
    const isUuid = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(id);

    const dbMatch = await prisma.payment.findFirst({
      where: isUuid ? { id: id } : { tranId: id },
      include: { user: true },
    });

    if (!dbMatch) {
      return res.status(404).json({ success: false, message: 'Payment record not found' });
    }

    // Atomically credit wallet, update payment to VALIDATED, and create transaction ledger entry
    await walletService.creditWalletForPayment(
      dbMatch.id,
      dbMatch.tranId,
      dbMatch.amount,
      dbMatch.userId,
      dbMatch.metadata || {}
    );

    const updatedPayment = await prisma.payment.findUnique({
      where: { id: dbMatch.id },
      include: { user: true },
    });

    try {
      await prisma.notification.create({
        data: {
          userId: updatedPayment.userId,
          title: 'Deposit Validated & Wallet Credited',
          message: `Your deposit of ৳${updatedPayment.amount} (Tran ID: ${updatedPayment.tranId}) has been validated by Admin and credited to your wallet balance.`,
          type: 'PAYMENT_SUCCESS',
        },
      });
    } catch (_e) {}

    if (updatedPayment.user?.email) {
      sendPaymentSuccessEmail({
        to: updatedPayment.user.email,
        fullName: updatedPayment.user.fullName,
        amount: Number(updatedPayment.amount),
        tranId: updatedPayment.tranId,
        paymentType: updatedPayment.paymentType,
      });
    }

    return res.json({
      success: true,
      message: `Payment ${updatedPayment.tranId} validated successfully by Admin. Wallet credited.`,
      payment: updatedPayment,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Manual Override Reject Payment (PATCH /api/payments/:id/reject)
 */
async function adminRejectPayment(req, res, next) {
  try {
    const { id } = req.params;
    const { note } = req.body || {};

    const isUuid = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(id);

    const dbMatch = await prisma.payment.findFirst({
      where: isUuid ? { id: id } : { tranId: id },
      include: { user: true },
    });

    if (!dbMatch) {
      return res.status(404).json({ success: false, message: 'Payment record not found' });
    }

    const updatedPayment = await prisma.payment.update({
      where: { id: dbMatch.id },
      data: { status: 'FAILED' },
      include: { user: true },
    });

    try {
      await prisma.notification.create({
        data: {
          userId: updatedPayment.userId,
          title: 'Payment Rejected',
          message: `Your payment of ৳${updatedPayment.amount} (${updatedPayment.paymentType}) with Tran ID ${updatedPayment.tranId} was rejected by Admin. Note: ${note || 'Rejected by administrator'}`,
          type: 'PAYMENT_FAILED',
        },
      });
    } catch (_e) {}

    if (updatedPayment.user?.email) {
      sendPaymentFailedEmail({
        to: updatedPayment.user.email,
        fullName: updatedPayment.user.fullName,
        amount: Number(updatedPayment.amount),
        tranId: updatedPayment.tranId,
        reason: note || 'Rejected by administrator',
      });
    }

    return res.json({
      success: true,
      message: `Payment ${updatedPayment.tranId} rejected by Admin`,
      payment: updatedPayment,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * Pay for Renter / Ekota Service using Wallet Balance
 * POST /api/payments/wallet
 */
async function payWithWallet(req, res, next) {
  try {
    const userId = req.user.id;
    const { amount, description, listingId } = req.body;

    const result = await walletService.payFromWallet({
      userId,
      amount,
      description: description || 'Renter Payment from Ekota Wallet',
      reference: `EKOTA-RENT-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      metadata: { listingId },
    });

    return res.status(200).json({
      success: true,
      message: 'Payment completed successfully using wallet balance.',
      transactionId: result.transactionId,
      newBalance: result.newBalance,
    });
  } catch (error) {
    if (error.statusCode === 400) {
      return res.status(400).json({ message: error.message });
    }
    return next(error);
  }
}

module.exports = {
  processPaymentValidation,
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
  payWithWallet,
};
