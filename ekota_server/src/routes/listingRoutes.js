const express = require('express');

const { authenticate } = require('../middleware/auth');
const {
  getProducerListings,
  createListing,
  getListingById,
  voteListing,
  getComments,
  postComment,
  replyComment,
  getReviews,
  canReview,
  postReview
} = require('../controllers/listingController');

const router = express.Router();

router.get('/producers/:producerId/listings', authenticate, getProducerListings);
router.get('/producers/listings', authenticate, getProducerListings);

router.post('/listings', authenticate, createListing);
router.get('/listings/:id', authenticate, getListingById);
router.post('/listings/:id/vote', authenticate, voteListing);

router.get('/listings/:id/comments', authenticate, getComments);
router.post('/listings/:id/comments', authenticate, postComment);
router.post('/comments/:commentId/reply', authenticate, replyComment);

router.get('/listings/:id/reviews', authenticate, getReviews);
router.get('/listings/:id/can-review', authenticate, canReview);
router.post('/listings/:id/reviews', authenticate, postReview);

module.exports = router;
