require('dotenv').config();

const { createApp } = require('./src/app');

const app = createApp();
const port = process.env.PORT || 5000;

const server = app.listen(port, '0.0.0.0', () => {
  console.log(`Ekota backend running on port ${port} (0.0.0.0)`);
});

const socketManager = require('./src/services/socketManager');
socketManager.init(server);

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`Error: Port ${port} is already in use by another process.`);
  } else {
    console.error('Server error:', error);
  }
  process.exit(1);
});