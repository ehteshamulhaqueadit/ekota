const express = require('express');
const { authenticate } = require('../middleware/auth');
const {
  addToWatchlist,
  removeFromWatchlist,
  updateWatchlistAlerts,
  getMyWatchlist
} = require('../controllers/watchlistController');

const router = express.Router();

router.post('/watchlist', authenticate, addToWatchlist);
router.delete('/watchlist/:listingId', authenticate, removeFromWatchlist);
router.put('/watchlist/:listingId', authenticate, updateWatchlistAlerts);
router.get('/watchlist/my', authenticate, getMyWatchlist);

module.exports = router;
