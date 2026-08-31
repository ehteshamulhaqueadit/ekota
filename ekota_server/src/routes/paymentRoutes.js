const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { authenticate } = require('../middleware/auth');

// Public callback routes for SSLCommerz redirect
router.all('/success', paymentController.handleSuccess);
router.all('/fail', paymentController.handleFail);
router.all('/cancel', paymentController.handleCancel);
router.all('/ipn', paymentController.handleIPN);

// Protected routes requiring authentication
router.use(authenticate);

router.post('/initiate', paymentController.initiatePayment);
router.get('/my', paymentController.getUserPayments);
router.get('/admin/all', paymentController.getAllPayments);
router.get('/:id', paymentController.getPaymentById);

// Admin Validation & Rejection Routes
router.patch('/:id/validate', paymentController.adminValidatePayment);
router.patch('/:id/approve', paymentController.adminValidatePayment);
router.patch('/:id/reject', paymentController.adminRejectPayment);

module.exports = router;
