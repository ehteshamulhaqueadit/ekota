const prisma = require('../config/prisma');

// Get all listings for a specific producer (fallback for empty ID handled by middleware check or param)
async function getProducerListings(req, res) {
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
  const isInvestor = req.user.role === 'INVESTOR';
  res.json({ canReview: isInvestor });
}

// Post a review
async function postReview(req, res) {
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
