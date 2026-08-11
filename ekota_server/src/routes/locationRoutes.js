const express = require('express');
const { authenticate } = require('../middleware/auth');
const {
  getProductLocation,
  updateProductLocation,
  subscribeToLocation,
  unsubscribeFromLocation,
  getMySubscriptions
} = require('../controllers/locationController');

const router = express.Router();

router.get('/location/subscriptions/my', authenticate, getMySubscriptions);
router.get('/location/:listingId', authenticate, getProductLocation);
router.put('/location/:listingId', authenticate, updateProductLocation);
router.post('/location/subscribe/:listingId', authenticate, subscribeToLocation);
router.delete('/location/subscribe/:listingId', authenticate, unsubscribeFromLocation);

module.exports = router;
