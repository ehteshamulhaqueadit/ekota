//Connects API endpoints to controller logic
const express = require('express');
const router = express.Router();
const kycController = require('../controllers/kycController');
const { authenticate } = require('../middleware/auth');

// Note: /api/webhooks/didit should be unprotected, but others are protected

router.get('/me', authenticate, kycController.getMyProfile);
router.post('/kyc/initiate', authenticate, kycController.initiateKyc);
router.get('/kyc/status', authenticate, kycController.syncKycStatus);

// Webhook destination for Didit
router.post('/webhooks/didit', kycController.handleWebhook);

module.exports = router;
