const socketIo = require('socket.io');

let io;
const userSockets = new Map(); // userId -> Set of socketIds

function init(server) {
  io = socketIo(server, {
    cors: {
      origin: '*', // Adjust for production
      methods: ['GET', 'POST', 'PUT', 'DELETE']
    }
  });

  io.on('connection', (socket) => {
    console.log(`[Socket.io] New client connected: ${socket.id}`);

    // Expect the client to emit an 'authenticate' event with their userId after connecting
    socket.on('authenticate', (userId) => {
      if (userId) {
        if (!userSockets.has(userId)) {
          userSockets.set(userId, new Set());
        }
        userSockets.get(userId).add(socket.id);
        socket.userId = userId; // attach userId to the socket
        console.log(`[Socket.io] User ${userId} authenticated with socket ${socket.id}`);
      }
    });

    socket.on('disconnect', () => {
      console.log(`[Socket.io] Client disconnected: ${socket.id}`);
      if (socket.userId && userSockets.has(socket.userId)) {
        const sockets = userSockets.get(socket.userId);
        sockets.delete(socket.id);
        if (sockets.size === 0) {
          userSockets.delete(socket.userId);
        }
      }
    });
  });
}

function sendToUser(userId, event, data) {
  if (io && userSockets.has(userId)) {
    const sockets = userSockets.get(userId);
    sockets.forEach(socketId => {
      io.to(socketId).emit(event, data);
    });
    return true;
  }
  return false;
}

module.exports = {
  init,
  sendToUser
};
