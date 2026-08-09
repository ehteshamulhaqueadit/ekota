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

// Get a specific listing by ID
async function getListingById(req, res) {
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
    const listing = await prisma.listing.findUnique({ where: { id } });
    if (!listing) return res.status(404).json({ error: 'Listing not found' });
    res.json({ ...listing, investorCount: 0 });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch listing' });
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
  voteListing,
  getComments,
  postComment,
  replyComment,
  getReviews,
  canReview,
  postReview
};
