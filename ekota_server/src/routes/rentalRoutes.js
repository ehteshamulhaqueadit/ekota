const express = require('express');
const { authenticate } = require('../middleware/auth');
const {
  listInRentalPool,
  getRentalPool,
  rentProduct,
  returnProduct,
  getMyRentals
} = require('../controllers/rentalController');

const router = express.Router();

router.post('/rental-pool', authenticate, listInRentalPool);
router.get('/rental-pool', authenticate, getRentalPool);
router.post('/rental-pool/:id/rent', authenticate, rentProduct);
router.post('/rental-pool/:id/return', authenticate, returnProduct);
router.get('/rentals/my', authenticate, getMyRentals);

module.exports = router;
