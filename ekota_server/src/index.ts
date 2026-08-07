import express from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';

const app = express();
const prisma = new PrismaClient();
const port = 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_ekota_key';

app.use(cors());
app.use(express.json());

// Middleware to mock extracting user from JWT
const authMiddleware = async (req: express.Request, res: express.Response, next: express.NextFunction) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || authHeader.includes('null')) {
    let user = await prisma.user.findFirst({ where: { role: 'producer' } });
    if (!user) {
      user = await prisma.user.create({
        data: { email: 'producer@test.com', name: 'Test Producer', role: 'producer' }
      });
    }
    (req as any).user = user;
    return next();
  }
  
  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, JWT_SECRET) as any;
    (req as any).user = payload;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// ==========================================
// LISTING ROUTES
// ==========================================

// Get all listings for a specific producer (fallback for empty ID)
app.get(['/api/producers/:producerId/listings', '/api/producers/listings'], authMiddleware, async (req, res) => {
  const producerId = req.params.producerId || (req as any).user.id;
  const listings = await prisma.listing.findMany({
    where: { producerId },
    orderBy: { createdAt: 'desc' }
  });
  const formatted = listings.map(l => ({ ...l, investorCount: 0 }));
  res.json(formatted);
});

// Create a new listing
app.post('/api/listings', authMiddleware, async (req, res) => {
  const producerId = (req as any).user.id;
  try {
    const listing = await prisma.listing.create({
      data: { ...req.body, producerId }
    });
    res.status(201).json(listing);
  } catch (error) {
    res.status(400).json({ error: 'Failed to create listing', details: String(error) });
  }
});

// Get a specific listing by ID
app.get('/api/listings/:id', authMiddleware, async (req, res) => {
  const { id } = req.params;
  const listing = await prisma.listing.findUnique({ where: { id } });
  if (!listing) return res.status(404).json({ error: 'Listing not found' });
  res.json({ ...listing, investorCount: 0 });
});

// Vote on a listing
app.post('/api/listings/:id/vote', authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { type } = req.body; 
  let updateData = {};
  if (type === 'upvote') updateData = { upvotes: { increment: 1 } };
  else if (type === 'downvote') updateData = { downvotes: { increment: 1 } };
  
  const listing = await prisma.listing.update({ where: { id }, data: updateData });
  res.json(listing);
});

// ==========================================
// COMMENT ROUTES
// ==========================================

// Get comments for a listing
app.get('/api/listings/:id/comments', authMiddleware, async (req, res) => {
  const { id } = req.params;
  const comments = await prisma.comment.findMany({
    where: { listingId: id },
    include: { author: true },
    orderBy: { createdAt: 'desc' }
  });
  // Format for Flutter: flatten author name
  const formatted = comments.map(c => ({
    id: c.id,
    listingId: c.listingId,
    authorId: c.authorId,
    authorName: c.author.name,
    text: c.text,
    reply: c.reply,
    createdAt: c.createdAt
  }));
  res.json(formatted);
});

// Post a comment
app.post('/api/listings/:id/comments', authMiddleware, async (req, res) => {
  const { id: listingId } = req.params;
  const { text } = req.body;
  const authorId = (req as any).user.id;

  const comment = await prisma.comment.create({
    data: { text, listingId, authorId },
    include: { author: true }
  });
  res.status(201).json({
    id: comment.id,
    listingId: comment.listingId,
    authorId: comment.authorId,
    authorName: comment.author.name,
    text: comment.text,
    reply: comment.reply,
    createdAt: comment.createdAt
  });
});

// Reply to a comment
app.post('/api/comments/:commentId/reply', authMiddleware, async (req, res) => {
  const { commentId } = req.params;
  const { text } = req.body;

  const comment = await prisma.comment.update({
    where: { id: commentId },
    data: { reply: text },
    include: { author: true }
  });
  res.json({
    id: comment.id,
    listingId: comment.listingId,
    authorId: comment.authorId,
    authorName: comment.author.name,
    text: comment.text,
    reply: comment.reply,
    createdAt: comment.createdAt
  });
});

// ==========================================
// REVIEW ROUTES
// ==========================================

// Get reviews for a listing
app.get('/api/listings/:id/reviews', authMiddleware, async (req, res) => {
  const { id } = req.params;
  const reviews = await prisma.review.findMany({
    where: { listingId: id },
    include: { author: true },
    orderBy: { createdAt: 'desc' }
  });
  const formatted = reviews.map(r => ({
    id: r.id,
    listingId: r.listingId,
    authorId: r.authorId,
    authorName: r.author.name,
    rating: r.rating,
    text: r.text,
    createdAt: r.createdAt
  }));
  res.json(formatted);
});

// Can review
app.get('/api/listings/:id/can-review', authMiddleware, async (req, res) => {
  // Mock logic: allow if investor
  const isInvestor = (req as any).user.role === 'investor';
  res.json({ canReview: isInvestor });
});

// Post a review
app.post('/api/listings/:id/reviews', authMiddleware, async (req, res) => {
  const { id: listingId } = req.params;
  const { rating, text } = req.body;
  const authorId = (req as any).user.id;

  const review = await prisma.review.create({
    data: { rating, text, listingId, authorId },
    include: { author: true }
  });
  res.status(201).json({
    id: review.id,
    listingId: review.listingId,
    authorId: review.authorId,
    authorName: review.author.name,
    rating: review.rating,
    text: review.text,
    createdAt: review.createdAt
  });
});

app.listen(port, () => {
  console.log(`Ekota Backend Server running on http://0.0.0.0:${port}`);
});
