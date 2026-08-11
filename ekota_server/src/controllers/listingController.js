const prisma = require('../config/prisma');

async function getProducerStats(req, res) {
  const producerId = req.params.producerId || req.user.id;

  try {
    const listings = await prisma.listing.findMany({
      where: { producerId },
      select: {
        campaignStatus: true,
        reviews: {
          select: {
            rating: true,
            authorId: true,
            author: {
              select: {
                role: true
              }
            }
          }
        }
      }
    });

    const completedListings = listings.filter(
      (listing) => String(listing.campaignStatus).toUpperCase() === 'DELIVERED'
    );
    const activeListings = listings.filter(
      (listing) => String(listing.campaignStatus).toUpperCase() !== 'DELIVERED'
    );

    const reviews = listings.flatMap((listing) => listing.reviews);
    const investorIds = new Set(
      reviews
        .filter((review) => review.author.role === 'INVESTOR')
        .map((review) => review.authorId)
    );
    const ratingTotal = reviews.reduce((sum, review) => sum + review.rating, 0);

    res.json({
      gigsCompleted: completedListings.length,
      gigsCurrentlyListed: activeListings.length,
      investors: investorIds.size,
      rating: reviews.length > 0 ? ratingTotal / reviews.length : 0
    });
  } catch (error) {
    console.error('Error fetching producer stats:', error);
    res.status(500).json({ error: 'Failed to fetch producer stats' });
  }
}

// Get all listings for a specific producer (fallback for empty ID handled by middleware check or param)
async function getProducerListings(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const producerId = req.params.producerId || req.user.id;
  try {
    const listings = await prisma.listing.findMany({
      where: { producerId },
      orderBy: { createdAt: 'desc' }
    });
    const formatted = listings.map(l => ({ ...l, investorCount: 0 }));
    res.json(formatted);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch listings' });
  }
}

// Create a new listing
async function createListing(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const producerId = req.user.id;
  try {
    const listing = await prisma.listing.create({
      data: { ...req.body, producerId }
    });
    res.status(201).json(listing);
  } catch (error) {
    res.status(400).json({ error: 'Failed to create listing', details: String(error) });
  }
}

// Get a specific listing by ID (enhanced with investment + rental data)
async function getListingById(req, res) {
  const { id } = req.params;
  try {
    const listing = await prisma.listing.findUnique({
      where: { id },
      include: {
        producer: { select: { id: true, fullName: true } },
        investments: {
          select: {
            id: true,
            userId: true,
            amount: true,
            sharePercentage: true,
            user: { select: { fullName: true } }
          }
        },
        rentalPoolItem: {
          select: {
            id: true,
            currentRentPrice: true,
            status: true
          }
        },
        warehouseStorage: {
          select: {
            id: true,
            monthlyFee: true,
            isActive: true,
            storedAt: true
          }
        },
        productLocation: {
          select: {
            latitude: true,
            longitude: true,
            address: true,
            updatedAt: true
          }
        }
      }
    });
    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    res.json({
      ...listing,
      investorCount: listing.investments.length,
      fundingPercentage: listing.fundingTarget > 0
        ? (listing.currentFunded / listing.fundingTarget) * 100
        : 0
    });
  } catch (error) {
    console.error('Error fetching listing:', error);
    res.status(500).json({ error: 'Failed to fetch listing' });
  }
}

// POST /api/listings/:id/confirm-delivery - Producer confirms order delivery
async function confirmDelivery(req, res) {
  const producerId = req.user.id;
  const { id } = req.params;

  try {
    const listing = await prisma.listing.findUnique({ where: { id } });
    if (!listing) return res.status(404).json({ error: 'Listing not found' });

    if (listing.producerId !== producerId) {
      return res.status(403).json({ error: 'Only the producer can confirm delivery' });
    }

    const validStatuses = ['FULLY_FUNDED', 'IN_PRODUCTION'];
    if (!validStatuses.includes(listing.campaignStatus.toUpperCase())) {
      return res.status(400).json({
        error: `Cannot confirm delivery. Current status: ${listing.campaignStatus}. Must be FULLY_FUNDED or IN_PRODUCTION.`
      });
    }

    const updated = await prisma.listing.update({
      where: { id },
      data: {
        campaignStatus: 'DELIVERED',
        isDelivered: true
      }
    });

    res.json({
      listing: updated,
      message: 'Order confirmed and marked as delivered'
    });
  } catch (error) {
    console.error('Error confirming delivery:', error);
    res.status(500).json({ error: 'Failed to confirm delivery' });
  }
}

// Vote on a listing
async function voteListing(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const { id } = req.params;
  const { type } = req.body; 
  let updateData = {};
  if (type === 'upvote') updateData = { upvotes: { increment: 1 } };
  else if (type === 'downvote') updateData = { downvotes: { increment: 1 } };
  
  try {
    const listing = await prisma.listing.update({ where: { id }, data: updateData });
    res.json(listing);
  } catch (error) {
    res.status(400).json({ error: 'Failed to vote' });
  }
}

// Get comments for a listing
async function getComments(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const { id } = req.params;
  try {
    const comments = await prisma.comment.findMany({
      where: { listingId: id },
      include: { author: true },
      orderBy: { createdAt: 'desc' }
    });
    const formatted = comments.map(c => ({
      id: c.id,
      listingId: c.listingId,
      authorId: c.authorId,
      authorName: c.author.fullName,
      text: c.text,
      reply: c.reply,
      createdAt: c.createdAt
    }));
    res.json(formatted);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
}

// Post a comment
async function postComment(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const { id: listingId } = req.params;
  const { text } = req.body;
  const authorId = req.user.id;

  try {
    const comment = await prisma.comment.create({
      data: { text, listingId, authorId },
      include: { author: true }
    });
    res.status(201).json({
      id: comment.id,
      listingId: comment.listingId,
      authorId: comment.authorId,
      authorName: comment.author.fullName,
      text: comment.text,
      reply: comment.reply,
      createdAt: comment.createdAt
    });
  } catch (error) {
    res.status(400).json({ error: 'Failed to post comment' });
  }
}

// Reply to a comment
async function replyComment(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const { commentId } = req.params;
  const { text } = req.body;

  try {
    const comment = await prisma.comment.update({
      where: { id: commentId },
      data: { reply: text },
      include: { author: true }
    });
    res.json({
      id: comment.id,
      listingId: comment.listingId,
      authorId: comment.authorId,
      authorName: comment.author.fullName,
      text: comment.text,
      reply: comment.reply,
      createdAt: comment.createdAt
    });
  } catch (error) {
    res.status(400).json({ error: 'Failed to reply to comment' });
  }
}

// Get reviews for a listing
async function getReviews(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const { id } = req.params;
  try {
    const reviews = await prisma.review.findMany({
      where: { listingId: id },
      include: { author: true },
      orderBy: { createdAt: 'desc' }
    });
    const formatted = reviews.map(r => ({
      id: r.id,
      listingId: r.listingId,
      authorId: r.authorId,
      authorName: r.author.fullName,
      rating: r.rating,
      text: r.text,
      createdAt: r.createdAt
    }));
    res.json(formatted);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch reviews' });
  }
}

// Can review
async function canReview(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const isInvestor = req.user.role === 'INVESTOR';
  res.json({ canReview: isInvestor });
}

// Post a review
async function postReview(req, res) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  const { id: listingId } = req.params;
  const { rating, text } = req.body;
  const authorId = req.user.id;

  try {
    const review = await prisma.review.create({
      data: { rating, text, listingId, authorId },
      include: { author: true }
    });
    res.status(201).json({
      id: review.id,
      listingId: review.listingId,
      authorId: review.authorId,
      authorName: review.author.fullName,
      rating: review.rating,
      text: review.text,
      createdAt: review.createdAt
    });
  } catch (error) {
    res.status(400).json({ error: 'Failed to post review' });
  }
}

module.exports = {
  getProducerStats,
  getProducerListings,
  createListing,
  getListingById,
  confirmDelivery,
  voteListing,
  getComments,
  postComment,
  replyComment,
  getReviews,
  canReview,
  postReview
};
