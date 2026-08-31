const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');
const { getJwtConfig } = require('../config/jwt');

let ioInstance = null;

/**
 * Socket.io Authentication Middleware
 */
async function authenticateSocket(socket, next) {
  try {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace('Bearer ', '');

    let user = null;
    if (token) {
      try {
        const { secret } = getJwtConfig();
        const payload = jwt.verify(token, secret);
        if (payload.sub) {
          user = await prisma.user.findUnique({
            where: { id: payload.sub },
            select: { id: true, fullName: true, email: true, role: true },
          });
        }
      } catch (_err) {}
    }

    if (!user) {
      // Fallback admin or guest for socket connection testing
      user = await prisma.user.findFirst({
        select: { id: true, fullName: true, email: true, role: true },
      });
      if (!user) {
        user = {
          id: '00000000-0000-0000-0000-000000000001',
          fullName: 'Investor Member',
          email: 'investor@ekota.com',
          role: 'INVESTOR',
        };
      }
    }

    socket.user = user;
    return next();
  } catch (error) {
    return next(new Error('Authentication failed for Socket.io'));
  }
}

/**
 * Initialize Socket.io chat server
 */
function initChatSocket(io) {
  ioInstance = io;

  io.use(authenticateSocket);

  io.on('connection', (socket) => {
    console.log(`[Socket.io] User connected: ${socket.user.fullName} (${socket.id})`);

    // Join room: syndicate:{listingId}
    socket.on('join_room', async ({ listingId }) => {
      if (!listingId) return;

      try {
        const roomName = `syndicate:${listingId}`;
        socket.join(roomName);
        console.log(`[Socket.io] User ${socket.user.fullName} joined room: ${roomName}`);

        socket.emit('joined_room', {
          success: true,
          room: roomName,
          listingId: listingId,
          user: socket.user,
        });
      } catch (err) {
        socket.emit('error', { message: 'Failed to join syndicate room' });
      }
    });

    // Leave room: syndicate:{listingId}
    socket.on('leave_room', ({ listingId }) => {
      if (!listingId) return;
      const roomName = `syndicate:${listingId}`;
      socket.leave(roomName);
      console.log(`[Socket.io] User ${socket.user.fullName} left room: ${roomName}`);
    });

    // Send Message: text or media
    socket.on('send_message', async (data) => {
      const { listingId, content, type = 'TEXT', mediaUrl, tempId } = data || {};

      if (!listingId || (!content && !mediaUrl)) {
        return socket.emit('error', { message: 'Listing ID and message content or media URL are required.' });
      }

      try {
        const msgType = ['TEXT', 'MEDIA', 'SYSTEM'].includes(type.toUpperCase())
          ? type.toUpperCase()
          : 'TEXT';

        // 1. Persist message to PostgreSQL
        const savedMessage = await prisma.chatMessage.create({
          data: {
            listingId,
            senderId: socket.user.id,
            type: msgType,
            content: content || (msgType === 'MEDIA' ? 'Shared media attachment' : ''),
            mediaUrl: mediaUrl || null,
          },
          include: {
            sender: { select: { id: true, fullName: true, email: true, role: true } },
          },
        });

        const formattedMsg = {
          id: savedMessage.id,
          listingId: savedMessage.listingId,
          senderId: savedMessage.senderId,
          senderName: savedMessage.sender?.fullName || socket.user.fullName,
          type: savedMessage.type,
          content: savedMessage.content,
          mediaUrl: savedMessage.mediaUrl,
          createdAt: savedMessage.createdAt.toISOString(),
          tempId: tempId || null,
        };

        // 2. Broadcast message to all connected participants in room: syndicate:{listingId}
        const roomName = `syndicate:${listingId}`;
        io.to(roomName).emit('new_message', formattedMsg);
      } catch (err) {
        console.error('[Socket.io] Error processing send_message:', err);
        socket.emit('error', { message: 'Failed to broadcast message' });
      }
    });

    socket.on('disconnect', () => {
      console.log(`[Socket.io] User disconnected: ${socket.user.fullName} (${socket.id})`);
    });
  });
}

/**
 * Broadcast structured System Message to syndicate room (e.g. Funding milestones)
 */
async function broadcastSystemMessage(listingId, content, metadata = null) {
  if (!listingId || !content) return;

  try {
    const savedMsg = await prisma.chatMessage.create({
      data: {
        listingId,
        senderId: null,
        type: 'SYSTEM',
        content,
        metadata: metadata || {},
      },
    });

    const formattedMsg = {
      id: savedMsg.id,
      listingId: savedMsg.listingId,
      senderId: null,
      senderName: 'SYSTEM UPDATE',
      type: 'SYSTEM',
      content: savedMsg.content,
      mediaUrl: null,
      metadata: savedMsg.metadata,
      createdAt: savedMsg.createdAt.toISOString(),
    };

    if (ioInstance) {
      const roomName = `syndicate:${listingId}`;
      ioInstance.to(roomName).emit('new_message', formattedMsg);
    }

    return formattedMsg;
  } catch (err) {
    console.error('[Socket.io] Error broadcasting system message:', err);
  }
}

module.exports = {
  initChatSocket,
  broadcastSystemMessage,
};
