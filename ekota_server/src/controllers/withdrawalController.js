const prisma = require('../config/prisma');
const { sendNotificationEmail } = require('../services/emailService');

/**
 * Get or initialize Producer Balance
 */
async function getProducerBalance(req, res, next) {
  try {
    const producerId = req.user.id;

    let balance = await prisma.producerBalance.findUnique({
      where: { producerId },
    });

    if (!balance) {
      // Default initialization with demo earnings for testing if new producer
      balance = await prisma.producerBalance.create({
        data: {
          producerId,
          totalEarnings: 25000.0,
          availableBalance: 25000.0,
          pendingWithdrawal: 0.0,
          totalWithdrawn: 0.0,
        },
      });
    }

    return res.json({ balance });
  } catch (error) {
    return next(error);
  }
}

/**
 * Producer submits a withdrawal request
 */
async function requestWithdrawal(req, res, next) {
  try {
    const producerId = req.user.id;
    const { amount, method = 'BANK_TRANSFER', accountDetails } = req.body;

    const reqAmount = Number(amount);
    if (!reqAmount || isNaN(reqAmount) || reqAmount <= 0) {
      return res.status(400).json({ message: 'Valid positive amount is required' });
    }

    if (!accountDetails || typeof accountDetails !== 'object') {
      return res.status(400).json({ message: 'Account details are required' });
    }

    const validMethods = ['BANK_TRANSFER', 'BKASH', 'NAGAD', 'ROCKET'];
    if (!validMethods.includes(method.toUpperCase())) {
      return res.status(400).json({ message: `Invalid method. Must be one of: ${validMethods.join(', ')}` });
    }

    // Atomic transaction to verify balance and lock funds
    const result = await prisma.$transaction(async (tx) => {
      let balance = await tx.producerBalance.findUnique({ where: { producerId } });

      if (!balance) {
        // Initialize if empty
        balance = await tx.producerBalance.create({
          data: {
            producerId,
            totalEarnings: 25000.0,
            availableBalance: 25000.0,
            pendingWithdrawal: 0.0,
            totalWithdrawn: 0.0,
          },
        });
      }

      if (Number(balance.availableBalance) < reqAmount) {
        throw new Error('INSUFFICIENT_BALANCE');
      }

      // Update balance
      const updatedBalance = await tx.producerBalance.update({
        where: { producerId },
        data: {
          availableBalance: { decrement: reqAmount },
          pendingWithdrawal: { increment: reqAmount },
        },
      });

      // Create request
      const withdrawalRequest = await tx.withdrawalRequest.create({
        data: {
          producerId,
          amount: reqAmount,
          method: method.toUpperCase(),
          accountDetails,
          status: 'PENDING',
        },
      });

      return { updatedBalance, withdrawalRequest };
    });

    return res.status(201).json({
      message: 'Withdrawal request submitted successfully',
      withdrawalRequest: result.withdrawalRequest,
      balance: result.updatedBalance,
    });
  } catch (error) {
    if (error.message === 'INSUFFICIENT_BALANCE') {
      return res.status(400).json({ message: 'Insufficient available balance for withdrawal' });
    }
    return next(error);
  }
}

/**
 * Get Producer's own withdrawal requests
 */
async function getMyWithdrawalRequests(req, res, next) {
  try {
    const producerId = req.user.id;
    const requests = await prisma.withdrawalRequest.findMany({
      where: { producerId },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ requests });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Get all withdrawal requests
 */
async function getAllWithdrawalRequests(req, res, next) {
  try {
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ message: 'Access denied. Admin required.' });
    }

    const { status } = req.query;

    const where = {};
    if (status) {
      where.status = status.toUpperCase();
    }

    const requests = await prisma.withdrawalRequest.findMany({
      where,
      include: {
        producer: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phoneNumber: true,
            kycStatus: true,
          },
        },
        reviewedBy: {
          select: {
            id: true,
            fullName: true,
            email: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ requests });
  } catch (error) {
    return next(error);
  }
}

/**
 * Admin: Process withdrawal request (Approve, Reject, Process)
 */
async function processWithdrawalRequest(req, res, next) {
  try {
    if (req.user.role !== 'ADMIN') {
      return res.status(403).json({ message: 'Access denied. Admin required.' });
    }

    const { id } = req.params;
    const { status, adminNote, transactionRef } = req.body;

    const targetStatus = status ? status.toUpperCase() : null;
    if (!['APPROVED', 'REJECTED', 'PROCESSED'].includes(targetStatus)) {
      return res.status(400).json({
        message: 'Invalid status. Must be APPROVED, REJECTED, or PROCESSED',
      });
    }

    const existingRequest = await prisma.withdrawalRequest.findUnique({
      where: { id },
      include: { producer: true },
    });

    if (!existingRequest) {
      return res.status(404).json({ message: 'Withdrawal request not found' });
    }

    if (existingRequest.status === targetStatus) {
      return res.status(400).json({ message: `Request is already in ${targetStatus} status` });
    }

    const amount = Number(existingRequest.amount);
    const producerId = existingRequest.producerId;

    const result = await prisma.$transaction(async (tx) => {
      // Update withdrawal request status
      const updatedRequest = await tx.withdrawalRequest.update({
        where: { id },
        data: {
          status: targetStatus,
          adminNote: adminNote || null,
          transactionRef: transactionRef || null,
          reviewedById: req.user.id,
          reviewedAt: new Date(),
        },
      });

      // Update Producer balance based on transition
      if (targetStatus === 'APPROVED' || targetStatus === 'PROCESSED') {
        if (existingRequest.status === 'PENDING') {
          await tx.producerBalance.update({
            where: { producerId },
            data: {
              pendingWithdrawal: { decrement: amount },
              totalWithdrawn: { increment: amount },
            },
          });
        }
      } else if (targetStatus === 'REJECTED') {
        if (existingRequest.status === 'PENDING') {
          await tx.producerBalance.update({
            where: { producerId },
            data: {
              pendingWithdrawal: { decrement: amount },
              availableBalance: { increment: amount },
            },
          });
        }
      }

      // Create Notification record for Producer
      const notifTitle =
        targetStatus === 'REJECTED'
          ? 'Withdrawal Request Rejected'
          : `Withdrawal Request ${targetStatus === 'PROCESSED' ? 'Processed' : 'Approved'}`;

      const notifMsg =
        targetStatus === 'REJECTED'
          ? `Your withdrawal request of ৳${amount} was rejected by Admin. Reason: ${adminNote || 'No specific reason provided'}.`
          : `Your withdrawal request of ৳${amount} via ${existingRequest.method} has been ${targetStatus.toLowerCase()}.${
              transactionRef ? ` Reference: ${transactionRef}` : ''
            }`;

      const notifType =
        targetStatus === 'REJECTED'
          ? 'WITHDRAWAL_REJECTED'
          : targetStatus === 'PROCESSED'
          ? 'WITHDRAWAL_PROCESSED'
          : 'WITHDRAWAL_APPROVED';

      await tx.notification.create({
        data: {
          userId: producerId,
          title: notifTitle,
          message: notifMsg,
          type: notifType,
          metadata: {
            withdrawalId: id,
            amount,
            status: targetStatus,
            transactionRef,
          },
        },
      });

      return { updatedRequest, notifTitle, notifMsg };
    });

    // Asynchronously send email to Producer
    sendNotificationEmail({
      to: existingRequest.producer.email,
      subject: `Ekota Payout Update - ${result.notifTitle}`,
      title: result.notifTitle,
      message: result.notifMsg,
    });

    return res.json({
      message: `Withdrawal request successfully ${targetStatus.toLowerCase()}`,
      request: result.updatedRequest,
    });
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
