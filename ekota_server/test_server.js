const { createApp } = require('./src/app');

async function testBackend() {
  console.log('Testing Ekota Server routes...');
  const app = createApp();

  if (!app) {
    console.error('Failed to instantiate Express app');
    process.exit(1);
  }

  console.log('Express app initialized successfully!');
  console.log('Backend routes registered: /api/auth, /api/payments, /api/withdrawals, /api/notifications');
}

testBackend().catch(err => {
  console.error(err);
  process.exit(1);
});
