const path = require('path');
const fs = require('fs');
const prisma = require('../config/prisma');

/**
 * Get active syndicate asset threads with live funding calculations from PostgreSQL
 * GET /api/chat/threads
 */
async function getSyndicateThreads(req, res, next) {
  try {
    const listings = await prisma.listing.findMany({
      include: {
        producer: { select: { id: true, fullName: true, email: true } },
        payments: { where: { status: 'VALIDATED' } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const threads = listings.map((listing) => {
      // Calculate current total raised from PostgreSQL VALIDATED payments
      const totalRaised = listing.payments.reduce((sum, p) => sum + Number(p.amount), 0);
      const target = Number(listing.fundingTarget) || 100000;
      const percentage = Math.min(100, Math.round((totalRaised / target) * 100));

      return {
        id: listing.id,
        assetName: listing.assetName,
        category: listing.category,
        fundingTarget: target,
        rentalPrice: Number(listing.rentalPrice),
        currentFunding: totalRaised,
        fundingPercentage: percentage,
        imageUrls: listing.imageUrls || [],
        producerName: listing.producer?.fullName || 'Producer',
        status: listing.status,
      };
    });

    return res.json({ success: true, threads });
  } catch (error) {
    return next(error);
  }
}

/**
 * Get persisted chat message history for a syndicate thread from PostgreSQL
 * GET /api/chat/history/:listingId
 */
async function getChatHistory(req, res, next) {
  try {
    const { listingId } = req.params;

    if (!listingId) {
      return res.status(400).json({ message: 'Listing ID is required' });
    }

    const messages = await prisma.chatMessage.findMany({
      where: { listingId },
      include: {
        sender: { select: { id: true, fullName: true, email: true, role: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    const formattedMessages = messages.map((m) => ({
      id: m.id,
      listingId: m.listingId,
      senderId: m.senderId,
      senderName: m.sender ? m.sender.fullName : 'SYSTEM UPDATE',
      type: m.type,
      content: m.content,
      mediaUrl: m.mediaUrl,
      metadata: m.metadata,
      createdAt: m.createdAt.toISOString(),
    }));

    return res.json({ success: true, messages: formattedMessages });
  } catch (error) {
    return next(error);
  }
}

/**
 * Upload chat media attachment (image / document)
 * POST /api/chat/upload
 */
async function uploadChatMedia(req, res, next) {
  try {
    const { base64Data, fileName } = req.body || {};

    if (!base64Data) {
      return res.status(400).json({ success: false, message: 'No file data provided' });
    }

    const cleanBase64 = base64Data.replace(/^data:[^;]+;base64,/, '');
    const buffer = Buffer.from(cleanBase64, 'base64');

    const uploadsDir = path.join(__dirname, '../../uploads');
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const fileExt = path.extname(fileName || 'attachment.jpg') || '.jpg';
    const uniqueName = `chat_${Date.now()}_${Math.random().toString(36).substring(2, 8)}${fileExt}`;
    const filePath = path.join(uploadsDir, uniqueName);

    fs.writeFileSync(filePath, buffer);

    const protocol = req.protocol || 'http';
    const host = req.get('host') || 'localhost:5000';
    const mediaUrl = `${protocol}://${host}/uploads/${uniqueName}`;

    return res.json({ success: true, mediaUrl, fileName: uniqueName });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getSyndicateThreads,
  getChatHistory,
  uploadChatMedia,
};
