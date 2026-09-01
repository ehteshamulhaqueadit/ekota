require('dotenv').config();
const http = require('http');
const { Server } = require('socket.io');
const { createApp } = require('./src/app');
const { seedDatabaseIfEmpty } = require('./src/utils/seedDatabase');
const { initChatSocket } = require('./src/socket/chatSocket');

const app = createApp();
const port = process.env.PORT || 5000;

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Attach Socket.io server for Real-Time Syndicate Chat
initChatSocket(io);

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`Error: Port ${port} is already in use by another process.`);
  } else {
    console.error('Server error:', error);
  }
  process.exit(1);
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Ekota backend & Socket.io server running on port ${port}`);
  seedDatabaseIfEmpty();
});