const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const prisma = require('../config/prisma');
const { getJwtConfig } = require('../config/jwt');
const { generateOtp } = require('../utils/otp');
const { sendOtpEmail } = require('../services/emailService');

const allowedRoles = new Set(['ADMIN', 'RENTER', 'INVESTOR', 'PRODUCER']);

function createToken(user) {
  const { secret, expiresIn } = getJwtConfig();

  return jwt.sign(
    {
      role: user.role,
      email: user.email
    },
    secret,
    {
      subject: user.id,
      expiresIn
    }
  );
}

function sanitizeUser(user) {
  return {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    phoneNumber: user.phoneNumber,
    role: user.role,
    isEmailVerified: user.isEmailVerified,
    isBlocked: user.isBlocked,
    blockedReason: user.blockedReason,
    kycStatus: user.kycStatus,
    diditSessionId: user.diditSessionId,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  };
}

async function signup(req, res, next) {
  
  try {
    const { email, password, fullName, phoneNumber, role } = req.body;

    if (!email || !password || !fullName || !role) {
      return res.status(400).json({ message: 'email, password, fullName, and role are required' });
    }

    if (!allowedRoles.has(role)) {
      return res.status(400).json({ message: 'Invalid role' });
    }

    const existingUser = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });

    if (existingUser) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await prisma.user.create({
      data: {
        email: email.toLowerCase(),
        passwordHash,
        fullName,
        phoneNumber,
        role
      }
    });

    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await prisma.otpVerification.create({
      data: {
        email: user.email,
        otpCode,
        expiresAt
      }
    });

    await sendOtpEmail({
      to: user.email,
      otpCode,
      purpose: 'account-verification'
    });

    return res.status(201).json({
      message: 'Account created successfully. Please verify your email with the OTP sent to Gmail.',
      user: sanitizeUser(user),
      verificationRequired: true
    });
  } catch (error) {
    return next(error);
  }
}

async function login(req, res, next) {
    // Print the entire request object (very verbose!)
  console.log(req);

  // Print request body (most common for POST/PUT)
  console.log('Body:', req.body);

  // Print query parameters (?id=123&name=test)
  console.log('Query:', req.query);

  // Print route parameters (/example/:id)
  console.log('Params:', req.params);

  // Print headers
  console.log('Headers:', req.headers);

  // Print method and URL
  console.log(`Method: ${req.method}, URL: ${req.url}`);
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'email and password are required' });
    }

    const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });

    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    if (!user.isEmailVerified) {
      return res.status(403).json({ message: 'Email not verified. Please verify your Gmail OTP first.' });
    }

    if (user.isBlocked) {
      return res.status(403).json({ message: 'Account is blocked', reason: user.blockedReason || null });
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);

    if (!passwordMatches) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = createToken(user);

    return res.json({
      message: 'Login successful',
      user: sanitizeUser(user),
      token
    });
  } catch (error) {
    return next(error);
  }
}

async function requestPasswordReset(req, res, next) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: 'email is required' });
    }

    const normalizedEmail = email.toLowerCase();
    const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });

    if (!user) {
      return res.status(200).json({ message: 'If the account exists, a reset OTP has been sent' });
    }

    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await prisma.otpVerification.create({
      data: {
        email: normalizedEmail,
        otpCode,
        expiresAt
      }
    });

    await sendOtpEmail({
      to: normalizedEmail,
      otpCode,
      purpose: 'password-reset'
    });

    return res.json({ message: 'Password reset OTP sent successfully' });
  } catch (error) {
    return next(error);
  }
}

async function requestRegistrationVerification(req, res, next) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: 'email is required' });
    }

    const normalizedEmail = email.toLowerCase();
    const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });

    if (!user) {
      return res.status(404).json({ message: 'Account not found' });
    }

    if (user.isEmailVerified) {
      return res.status(200).json({ message: 'Email is already verified' });
    }

    const otpCode = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await prisma.otpVerification.create({
      data: {
        email: normalizedEmail,
        otpCode,
        expiresAt
      }
    });

    await sendOtpEmail({
      to: normalizedEmail,
      otpCode,
      purpose: 'account-verification'
    });

    return res.json({ message: 'Registration verification OTP sent successfully' });
  } catch (error) {
    return next(error);
  }
}

async function confirmRegistration(req, res, next) {
  try {
    const { email, otpCode } = req.body;

    if (!email || !otpCode) {
      return res.status(400).json({ message: 'email and otpCode are required' });
    }

    const normalizedEmail = email.toLowerCase();
    const otpRecord = await prisma.otpVerification.findFirst({
      where: {
        email: normalizedEmail,
        otpCode,
        isUsed: false,
        expiresAt: {
          gt: new Date()
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    if (!otpRecord) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }

    const user = await prisma.user.update({
      where: { email: normalizedEmail },
      data: { isEmailVerified: true }
    });

    await prisma.otpVerification.update({
      where: { id: otpRecord.id },
      data: { isUsed: true }
    });

    return res.json({
      message: 'Email verified successfully',
      user: sanitizeUser(user)
    });
  } catch (error) {
    return next(error);
  }
}

async function verifyPasswordResetOtp(req, res, next) {
  try {
    const { email, otpCode, newPassword } = req.body;

    if (!email || !otpCode || !newPassword) {
      return res.status(400).json({ message: 'email, otpCode, and newPassword are required' });
    }

    const normalizedEmail = email.toLowerCase();

    const otpRecord = await prisma.otpVerification.findFirst({
      where: {
        email: normalizedEmail,
        otpCode,
        isUsed: false,
        expiresAt: {
          gt: new Date()
        }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    if (!otpRecord) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);

    await prisma.$transaction([
      prisma.user.update({
        where: { email: normalizedEmail },
        data: { passwordHash }
      }),
      prisma.otpVerification.update({
        where: { id: otpRecord.id },
        data: { isUsed: true }
      })
    ]);

    return res.json({ message: 'Password reset successful' });
  } catch (error) {
    return next(error);
  }
}

async function me(req, res) {
  return res.json({ user: sanitizeUser(req.user) });
}

module.exports = {
  signup,
  login,
  requestRegistrationVerification,
  confirmRegistration,
  requestPasswordReset,
  verifyPasswordResetOtp,
  me
};