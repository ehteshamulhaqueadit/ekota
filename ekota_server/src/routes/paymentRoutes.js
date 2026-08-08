const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { authenticate } = require('../middleware/auth');

// Public callback routes for SSLCommerz redirect/IPN
router.post('/success', paymentController.handleSuccess);
router.get('/success', paymentController.handleSuccess);
router.post('/fail', paymentController.handleFail);
router.get('/fail', paymentController.handleFail);
router.post('/cancel', paymentController.handleCancel);
router.get('/cancel', paymentController.handleCancel);
router.post('/ipn', paymentController.handleIPN);

// Protected routes
router.use(authenticate);

router.post('/initiate', paymentController.initiatePayment);
router.get('/my-payments', paymentController.getUserPayments);
router.get('/admin/all', paymentController.getAllPayments);
router.get('/:id', paymentController.getPaymentById);

module.exports = router;
