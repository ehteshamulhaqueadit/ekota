const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  getUsers,
  blockUser,
  unblockUser,
  getAllListings,
  updateListing,
  deleteListing,
  notifyProducer
} = require('../controllers/adminController');

// All admin routes require authentication and admin role
router.use(authenticate);
router.use(requireAdmin);

// User Management Routes
router.get('/users', getUsers);
router.post('/users/:id/block', blockUser);
router.post('/users/:id/unblock', unblockUser);

// Producer Post Management Routes
router.get('/listings', getAllListings);
router.put('/listings/:id', updateListing);
router.delete('/listings/:id', deleteListing);
router.post('/listings/:id/notify', notifyProducer);

module.exports = router;
