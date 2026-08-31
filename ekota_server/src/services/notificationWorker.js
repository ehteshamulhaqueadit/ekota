const prisma = require('../config/prisma');
const { sendNotificationJob, isPermanentFailure } = require('./notificationService');

const POLL_INTERVAL_MS = 5000;
const BATCH_SIZE = 20;
const BASE_BACKOFF_MS = 5000;
const MAX_BACKOFF_MS = 60 * 60 * 1000; // 1 hour
const MAX_ATTEMPTS = 10;
const STALE_PROCESSING_MS = 5 * 60 * 1000; // recover jobs stuck in PROCESSING after a crash
const FAILED_RETRY_COOLDOWN_MS = 30 * 60 * 1000; // give FAILED jobs a fresh chance later
const MAX_TOTAL_ATTEMPTS = MAX_ATTEMPTS + 5;

let polling = false;
let timer = null;

function nextAttemptAfter(attempts) {
  const backoff = Math.min(BASE_BACKOFF_MS * 2 ** attempts, MAX_BACKOFF_MS) + Math.floor(Math.random() * 1000);
  return new Date(Date.now() + backoff);
}

async function processJob(job) {
  // Claim the job so concurrent workers (or restarts) don't double-send.
  const claimed = await prisma.notificationJob.updateMany({
    where: { id: job.id, status: 'PENDING' },
    data: { status: 'PROCESSING' }
  });
  if (claimed.count === 0) return;

  try {
    await sendNotificationJob(job);
    await prisma.notificationJob.update({
      where: { id: job.id },
      data: { status: 'SENT', lastError: null }
    });
  } catch (err) {
    const attempts = job.attempts + 1;
    const permanent = isPermanentFailure(job.channel, err);
    const lastError = String((err && err.message) || err);

    if (permanent) {
      console.error(`[NotificationWorker] Permanent failure for ${job.channel} job ${job.id}:`, lastError);
      await prisma.notificationJob.update({
        where: { id: job.id },
        data: { status: 'FAILED', attempts, lastError }
      });
      return;
    }

    if (attempts >= MAX_ATTEMPTS) {
      console.error(`[NotificationWorker] ${job.channel} job ${job.id} failed after ${attempts} attempts:`, lastError);
      await prisma.notificationJob.update({
        where: { id: job.id },
        data: { status: 'FAILED', attempts, lastError }
      });
      return;
    }

    console.warn(`[NotificationWorker] ${job.channel} job ${job.id} attempt ${attempts} failed: ${lastError}. Scheduling retry.`);
    await prisma.notificationJob.update({
      where: { id: job.id },
      data: {
        status: 'PENDING',
        attempts,
        lastError,
        nextAttemptAt: nextAttemptAfter(attempts)
      }
    });
  }
}

async function processPending() {
  const jobs = await prisma.notificationJob.findMany({
    where: {
      status: 'PENDING',
      nextAttemptAt: { lte: new Date() }
    },
    orderBy: { createdAt: 'asc' },
    take: BATCH_SIZE
  });

  // Sequential dispatch is intentional: it keeps SMTP/FCM load low (Gmail
  // throttles burst sends) and respects the per-job timeout.
  for (const job of jobs) {
    await processJob(job);
  }
}

async function recoverStaleJobs() {
  // Jobs stuck in PROCESSING are recovered after a crash/restart mid-send.
  const cutoff = new Date(Date.now() - STALE_PROCESSING_MS);
  const recovered = await prisma.notificationJob.updateMany({
    where: { status: 'PROCESSING', updatedAt: { lte: cutoff } },
    data: { status: 'PENDING', nextAttemptAt: new Date() }
  });
  if (recovered.count > 0) {
    console.warn(`[NotificationWorker] Recovered ${recovered.count} stale PROCESSING job(s)`);
  }
}

async function requeueFailed() {
  // Transient failures (e.g. Gmail daily limit reset) eventually recover, so
  // give FAILED jobs a fresh retry cycle after a long cooldown.
  const cutoff = new Date(Date.now() - FAILED_RETRY_COOLDOWN_MS);
  const requeued = await prisma.notificationJob.updateMany({
    where: {
      status: 'FAILED',
      updatedAt: { lte: cutoff },
      attempts: { lt: MAX_TOTAL_ATTEMPTS }
    },
    data: { status: 'PENDING', nextAttemptAt: new Date() }
  });
  if (requeued.count > 0) {
    console.warn(`[NotificationWorker] Requeued ${requeued.count} FAILED job(s) for a fresh attempt`);
  }
}

async function poll() {
  if (polling) return;
  polling = true;
  try {
    await recoverStaleJobs();
    await processPending();
    await requeueFailed();
  } catch (err) {
    console.error('[NotificationWorker] Poll cycle error:', err);
  } finally {
    polling = false;
  }
}

function start() {
  if (timer) return;
  poll();
  timer = setInterval(poll, POLL_INTERVAL_MS);
  console.log(`[NotificationWorker] Started (poll interval ${POLL_INTERVAL_MS}ms)`);
}

function stop() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

module.exports = { start, stop };