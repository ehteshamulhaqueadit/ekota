const express = require('express');
const cors = require('cors');
const path = require('path');           // toha
const fs = require('fs');               // toha

const authRoutes = require('./routes/authRoutes');
const listingRoutes = require('./routes/listingRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const walletRoutes = require('./routes/walletRoutes');
const withdrawalRoutes = require('./routes/withdrawalRoutes');
const notificationRoutes = require('./routes/notificationRoutes');

// ======toha======
const adminRoutes = require('./routes/adminRoutes');
const chatRoutes = require('./routes/chatRoutes');

// ====== general ======
const investmentRoutes = require('./routes/investmentRoutes');
const rentalRoutes = require('./routes/rentalRoutes');
const votingRoutes = require('./routes/votingRoutes');
const warehouseRoutes = require('./routes/warehouseRoutes');
const locationRoutes = require('./routes/locationRoutes');
const watchlistRoutes = require('./routes/watchlistRoutes');

const { notFound, errorHandler } = require('./middleware/errorHandler');

function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: '50mb' }));              // toha
  app.use(express.urlencoded({ limit: '50mb', extended: true })); // toha

  // Serve static uploads directory for chat media attachments
  const uploadsDir = path.join(__dirname, '../uploads');
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }
  app.use('/uploads', express.static(uploadsDir));       // toha

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'ekota-backend' });
  });

  app.use('/api/auth', authRoutes);

  // ====== toha ======
  app.use('/api/admin', adminRoutes);
  app.use('/api/chat', chatRoutes);

  app.use('/api/wallet', walletRoutes);
  app.use('/api', listingRoutes);
  app.use('/api/payments', paymentRoutes);
  app.use('/api/withdrawals', withdrawalRoutes);
  app.use('/api/notifications', notificationRoutes);

  // ====== general======
  app.use('/api', investmentRoutes);
  app.use('/api', rentalRoutes);
  app.use('/api', votingRoutes);
  app.use('/api', warehouseRoutes);
  app.use('/api', locationRoutes);
  app.use('/api', watchlistRoutes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };