const nodemailer = require('nodemailer');
const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK with the service account
if (!admin.apps.length) {
  try {
    const serviceAccount = require(path.join(__dirname, '../../firebase/ekota-firebase-key.json'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('[Firebase] Admin SDK initialized successfully');
  } catch (error) {
    console.error('[Firebase] Failed to initialize Admin SDK:', error.message);
  }
}

// Hard timeouts so a send can never hang the process (Gmail SMTP and FCM are
// the usual culprits for the "return hangs / notification never arrives" bug).
const SMTP_TIMEOUT_MS = 15000;
const FCM_TIMEOUT_MS = 10000;

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
  connectionTimeout: SMTP_TIMEOUT_MS,
  greetingTimeout: SMTP_TIMEOUT_MS,
  socketTimeout: SMTP_TIMEOUT_MS,
});

function withTimeout(promise, ms, label) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(label)), ms);
    Promise.resolve(promise).then(
      (value) => { clearTimeout(timer); resolve(value); },
      (error) => { clearTimeout(timer); reject(error); }
    );
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getErrorCode(err) {
  if (!err) return '';
  if (err.code) return String(err.code);
  if (err.errorInfo && err.errorInfo.code) return String(err.errorInfo.code);
  return '';
}

/**
 * Build the durable notification jobs (email + FCM) for a list of watchers.
 * Pure function — safe to call with either the prisma client or a tx client.
 */
function buildWatchlistJobs(watchers, listing, type, message) {
  const assetName = listing && listing.assetName ? listing.assetName : 'Product';
  const listingId = listing && listing.id ? listing.id : '';
  const text = String(message).replace(/\{assetName\}/g, assetName);
  const subject = `Ekota Watchlist Alert: ${assetName}`;
  const jobs = [];

  for (const watch of watchers) {
    const user = watch && watch.user ? watch.user : null;
    if (!user) continue;

    if (user.email) {
      jobs.push({
        channel: 'email',
        userId: user.id,
        recipient: user.email,
        payload: {
          subject,
          html: `<p>Hello ${user.fullName || 'there'},</p><p>${text}</p>`
        }
      });
    }

    if (user.fcmToken) {
      jobs.push({
        channel: 'fcm',
        userId: user.id,
        recipient: user.fcmToken,
        payload: {
          title: 'Ekota Watchlist Alert',
          body: text,
          data: {
            listingId: String(listingId ?? ''),
            type: String(type ?? ''),
            assetName: String(assetName ?? '')
          },
          channelId: 'ekota_watchlist_channel'
        }
      });
    }
  }

  return jobs;
}

/**
 * Enqueue watchlist alert jobs for delivery. This is a fast DB write and does
 * NOT perform any network I/O — call it from request handlers so the response
 * is never blocked on SMTP/FCM. Pass the prisma client, or a transaction
 * client (tx) to enqueue atomically with the business change.
 */
async function dispatchWatchlistAlerts(client, watchers, listing, type, message) {
  const jobs = buildWatchlistJobs(watchers, listing, type, message);
  if (jobs.length === 0) return 0;
  await client.notificationJob.createMany({ data: jobs });
  return jobs.length;
}

// ─── Low-level sends (used by the background worker) ────────────────────────

async function sendEmail(to, payload) {
  const subject = payload && payload.subject;
  const html = payload && payload.html;
  const text = payload && payload.text;
  await withTimeout(
    transporter.sendMail({
      from: process.env.GMAIL_FROM || process.env.GMAIL_USER,
      to,
      subject,
      html,
      text
    }),
    SMTP_TIMEOUT_MS,
    'SMTP send timed out'
  );
  console.log(`[Email] Watchlist alert sent to ${to}`);
}

async function sendFcm(userId, token, payload) {
  if (!admin.messaging) {
    throw new Error('Firebase Admin SDK not initialized');
  }
  const body = payload && payload.body ? payload.body : 'Ekota notification';
  const title = payload && payload.title ? payload.title : 'Ekota';
  const data = payload && payload.data
    ? Object.fromEntries(Object.entries(payload.data).map(([k, v]) => [k, String(v)]))
    : undefined;
  const channelId = payload && payload.channelId ? payload.channelId : 'ekota_watchlist_channel';

  await withTimeout(
    admin.messaging().send({
      token,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: {
          channelId,
          sound: 'default'
        }
      }
    }),
    FCM_TIMEOUT_MS,
    'FCM send timed out'
  );
  console.log(`[FCM] Push notification sent to user ${userId}`);
}

/**
 * Execute a single queued job. Throws on failure; the worker decides whether
 * the failure is permanent (invalid token/address — no retry) or transient.
 */
async function sendNotificationJob(job) {
  const payload = job.payload || {};
  if (job.channel === 'email') {
    return sendEmail(job.recipient, payload);
  }
  return sendFcm(job.userId, job.recipient, payload);
}

/**
 * Classify a failure as permanent (no point retrying) vs transient.
 */
function isPermanentFailure(channel, err) {
  const code = getErrorCode(err);
  if (channel === 'fcm') {
    return [
      'messaging/invalid-argument',
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered',
      'messaging/missing-registration-token'
    ].includes(code);
  }
  const msg = String((err && err.message) || '');
  return /invalid login|authentication|invalid addressee|bad address|no recipients defined/i.test(msg);
}

/**
 * Legacy direct sender — kept for backwards compatibility. Sends email + FCM
 * concurrently with hard timeouts and never throws. Prefer enqueuing jobs via
 * dispatchWatchlistAlerts in request handlers.
 */
async function sendWatchlistAlert(user, listing, type, message) {
  const jobs = buildWatchlistJobs([{ user }], listing, type, message);
  const results = await Promise.allSettled(jobs.map((job) => sendNotificationJob(job)));
  results.forEach((result, i) => {
    if (result.status === 'rejected') {
      console.error(`[notificationService] ${jobs[i].channel} failed for user ${jobs[i].userId}:`, result.reason && result.reason.message);
    }
  });
}

module.exports = {
  sendWatchlistAlert,
  sendNotificationJob,
  isPermanentFailure,
  dispatchWatchlistAlerts,
  buildWatchlistJobs
};
