const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');
const { getJwtConfig } = require('../config/jwt');

async function authenticate(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Missing bearer token' });
  }

  try {
    const token = header.slice(7);
    const { secret } = getJwtConfig();
    const payload = jwt.verify(token, secret);

    let user;
    if (payload.sub) {
      user = await prisma.user.findUnique({ where: { id: payload.sub } });
    }

    if (!user) {
      return res.status(401).json({ message: 'Invalid or expired token user' });
    }

    if (user.isBlocked && user.role !== 'ADMIN') {
      return res.status(403).json({
        error: 'ACCOUNT_FROZEN',
        message: `Your account is temporarily blocked/frozen. Reason: ${user.blockedReason || 'Violation of guidelines.'}`
      });
    }

    req.user = user;
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired authentication token' });
  }
}

function requireAdmin(req, res, next) {
  if (req.user && req.user.role === 'ADMIN') {
    return next();
  }
  return res.status(403).json({ message: 'Access denied: Admin role required' });
}


module.exports = { authenticate, requireAdmin };