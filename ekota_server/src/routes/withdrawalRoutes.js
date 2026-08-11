const express = require('express');
const router = express.Router();
const withdrawalController = require('../controllers/withdrawalController');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// Balance and requests
router.get('/balance', withdrawalController.getProducerBalance);
router.post('/request', withdrawalController.requestWithdrawal);
router.post('/', withdrawalController.requestWithdrawal);
router.get('/my', withdrawalController.getMyWithdrawalRequests);
router.get('/my-requests', withdrawalController.getMyWithdrawalRequests);

// Admin routes
router.get('/', withdrawalController.getAllWithdrawalRequests);
router.get('/admin/all', withdrawalController.getAllWithdrawalRequests);
router.patch('/:id/approve', withdrawalController.approveWithdrawal);
router.patch('/:id/reject', withdrawalController.rejectWithdrawal);
router.patch('/:id/process', withdrawalController.processWithdrawalRequest);

module.exports = router;
