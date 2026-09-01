const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');
const { authenticate } = require('../middleware/auth');

// Require authentication for all wallet endpoints
router.use(authenticate);

router.get('/', walletController.getWallet);
router.get('/transactions', walletController.getTransactions);
router.post('/pay', walletController.payWithWallet);

module.exports = router;
