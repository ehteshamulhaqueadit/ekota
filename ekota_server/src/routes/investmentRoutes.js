const express = require('express');
const { authenticate } = require('../middleware/auth');
const {
  createInvestment,
  getMyInvestments,
  getListingInvestors,
  getFundingStatus,
  getAvailableListings
} = require('../controllers/investmentController');

const router = express.Router();

router.post('/investments', authenticate, createInvestment);
router.get('/investments/my', authenticate, getMyInvestments);
router.get('/listings/available', authenticate, getAvailableListings);
router.get('/listings/:id/investments', authenticate, getListingInvestors);
router.get('/listings/:id/funding-status', authenticate, getFundingStatus);

module.exports = router;
