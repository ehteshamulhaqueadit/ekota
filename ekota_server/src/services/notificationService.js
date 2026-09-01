const nodemailer = require('nodemailer');
const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK with the service account
if (!admin.apps.length) {
  try {
    const serviceAccount = require(path.join(__dirname, '../../firebase/ekota-60085-firebase-adminsdk-fbsvc-515607e95a.json'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('[Firebase] Admin SDK initialized successfully');
  } catch (error) {
    console.error('[Firebase] Failed to initialize Admin SDK:', error.message);
  }
}

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

async function sendWatchlistAlert(user, listing, type, message) {
  // 1. Send Email
  if (user.email) {
    try {
      await transporter.sendMail({
        from: process.env.GMAIL_FROM || process.env.GMAIL_USER,
        to: user.email,
        subject: `Ekota Watchlist Alert: ${listing.assetName}`,
        html: `<p>Hello ${user.fullName},</p><p>${message}</p>`
      });
      console.log(`[Email] Watchlist alert sent to ${user.email}`);
    } catch (e) {
      console.error('[Email Error] Failed to send email:', e);
    }
  }

  // 2. Send Push Notification via Firebase Cloud Messaging
  if (user.fcmToken) {
    try {
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: 'Ekota Watchlist Alert',
          body: message,
        },
        data: {
          listingId: String(listing.id ?? ''),
          type: String(type ?? ''),
          assetName: String(listing.assetName ?? ''),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'ekota_watchlist_channel',
            sound: 'default',
          }
        }
      });
      console.log(`[FCM] Push notification sent to user ${user.id}`);
    } catch (e) {
      console.error('[FCM Error] Failed to send push notification:', e.message);
    }
  } else {
    console.log(`[FCM] Skipped for user ${user.id} - no FCM token registered`);
  }
}

module.exports = {
  sendWatchlistAlert
};
