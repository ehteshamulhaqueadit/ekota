const express = require('express');
const router = express.Router();
const withdrawalController = require('../controllers/withdrawalController');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// Producer routes
router.get('/balance', withdrawalController.getProducerBalance);
router.post('/request', withdrawalController.requestWithdrawal);
router.post('/', withdrawalController.requestWithdrawal);
router.get('/my-requests', withdrawalController.getMyWithdrawalRequests);
router.get('/my', withdrawalController.getMyWithdrawalRequests);

// Admin routes
router.get('/admin/all', withdrawalController.getAllWithdrawalRequests);
router.get('/', withdrawalController.getAllWithdrawalRequests);
router.patch('/admin/:id/process', withdrawalController.processWithdrawalRequest);
router.patch('/:id/approve', withdrawalController.approveWithdrawal);
router.patch('/:id/reject', withdrawalController.rejectWithdrawal);

module.exports = router;
