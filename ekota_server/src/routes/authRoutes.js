const express = require('express');

const { authenticate } = require('../middleware/auth');
const {
  signup,
  login,
  requestRegistrationVerification,
  confirmRegistration,
  requestPasswordReset,
  verifyPasswordResetOtp,
  me,
  updateFcmToken
} = require('../controllers/authController');

const router = express.Router();

router.post('/signup', signup);
router.post('/login', login);
router.post('/registration/request-verification', requestRegistrationVerification);
router.post('/registration/confirm', confirmRegistration);
router.post('/password-reset/request', requestPasswordReset);
router.post('/password-reset/reset-password', verifyPasswordResetOtp);
router.get('/me', authenticate, me);
router.put('/fcm-token', authenticate, updateFcmToken);

module.exports = router;