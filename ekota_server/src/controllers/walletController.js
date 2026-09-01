const walletService = require('../services/walletService');

/**
 * GET /api/wallet
 * Fetch authenticated user's wallet details & balance
 */
async function getWallet(req, res, next) {
  try {
    const userId = req.user.id;
    const wallet = await walletService.getOrCreateWallet(userId);

    return res.json({
      walletId: wallet.id,
      balance: Number(wallet.balance).toFixed(2),
      currency: wallet.currency,
      status: wallet.status,
      createdAt: wallet.createdAt,
    });
  } catch (error) {
    return next(error);
  }
}

/**
 * GET /api/wallet/transactions
 * Fetch paginated wallet transactions for authenticated user
 */
async function getTransactions(req, res, next) {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 20 } = req.query;

    const result = await walletService.getWalletTransactions(userId, page, limit);
    return res.json(result);
  } catch (error) {
    return next(error);
  }
}

/**
 * POST /api/payments/wallet
 * Pay for Ekota services using available wallet balance safely
 */
async function payWithWallet(req, res, next) {
  try {
    const userId = req.user.id;
    const { amount, description, reference, metadata } = req.body;

    const result = await walletService.payFromWallet({
      userId,
      amount,
      description,
      reference,
      metadata,
    });

    return res.json({
      success: true,
      message: 'Payment completed successfully using wallet balance',
      data: result,
    });
  } catch (error) {
    if (error.statusCode === 400) {
      return res.status(400).json({ success: false, message: error.message });
    }
    return next(error);
  }
}

module.exports = {
  getWallet,
  getTransactions,
  payWithWallet,
};
