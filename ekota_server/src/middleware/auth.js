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

    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      return res.status(401).json({ message: 'User not found' });
    }

    req.user = user;
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

module.exports = { authenticate };