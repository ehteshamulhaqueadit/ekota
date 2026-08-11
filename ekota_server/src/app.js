const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');
const listingRoutes = require('./routes/listingRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const withdrawalRoutes = require('./routes/withdrawalRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const adminRoutes = require('./routes/adminRoutes');
const { notFound, errorHandler } = require('./middleware/errorHandler');

function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'ekota-backend' });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api', listingRoutes);
  app.use('/api/payments', paymentRoutes);
  app.use('/api/withdrawals', withdrawalRoutes);
  app.use('/api/notifications', notificationRoutes);


  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };