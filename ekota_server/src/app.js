const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');
const listingRoutes = require('./routes/listingRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const withdrawalRoutes = require('./routes/withdrawalRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const investmentRoutes = require('./routes/investmentRoutes');
const rentalRoutes = require('./routes/rentalRoutes');
const votingRoutes = require('./routes/votingRoutes');
const warehouseRoutes = require('./routes/warehouseRoutes');
const locationRoutes = require('./routes/locationRoutes');
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
  app.use('/api', investmentRoutes);
  app.use('/api', listingRoutes);
  app.use('/api/payments', paymentRoutes);
  app.use('/api/withdrawals', withdrawalRoutes);
  app.use('/api/notifications', notificationRoutes);
  app.use('/api', rentalRoutes);
  app.use('/api', votingRoutes);
  app.use('/api', warehouseRoutes);
  app.use('/api', locationRoutes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };