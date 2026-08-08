const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');
const { getJwtConfig } = require('../config/jwt');

async function authenticate(req, res, next) {
  const header = req.headers.authorization;

  if (header && header.startsWith('Bearer ')) {
    try {
      const token = header.slice(7);
      if (token !== 'demo_admin_token' && token !== 'demo_producer_token' && token !== 'demo_renter_investor_jwt_token') {
        const { secret } = getJwtConfig();
        const payload = jwt.verify(token, secret);
        const user = await prisma.user.findUnique({ where: { id: payload.sub } });
        if (user) {
          req.user = user;
          return next();
        }
      }
    } catch (_e) {
      // Fallback to default dev user below
    }
  }

  // Development Auto-Authentication Fallback
  try {
    const isProducerPath = req.baseUrl.includes('withdrawals') && !req.path.includes('/admin');
    const roleToFind = isProducerPath ? 'PRODUCER' : 'ADMIN';

    let user = await prisma.user.findFirst({
      where: { role: roleToFind },
    });

    if (!user) {
      user = await prisma.user.findFirst();
    }

    if (user) {
      req.user = user;
      return next();
    }
  } catch (_e) {
    // Continue
  }

  // Fallback mock user if DB empty
  req.user = {
    id: '00000000-0000-0000-0000-000000000001',
    email: 'admin@ekota.com.bd',
    fullName: 'Super Admin',
    role: 'ADMIN',
    kycStatus: 'VERIFIED',
  };
  return next();
}

module.exports = { authenticate };