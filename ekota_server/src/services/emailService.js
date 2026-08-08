const nodemailer = require('nodemailer');

function createTransport() {
  const gmailUser = process.env.GMAIL_USER;
  const gmailAppPassword = process.env.GMAIL_APP_PASSWORD;

  if (!gmailUser || !gmailAppPassword) {
    return null;
  }

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: gmailUser,
      pass: gmailAppPassword,
    },
  });
}

async function sendOtpEmail({ to, otpCode, purpose }) {
  const transporter = createTransport();
  if (!transporter) {
    console.log(`[Email Service Mock] OTP ${otpCode} sent to ${to}`);
    return;
  }

  const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;
  const subject =
    purpose === 'password-reset'
      ? 'Ekota password reset OTP'
      : 'Ekota account verification OTP';

  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.6">
      <h2>Ekota OTP Code</h2>
      <p>Your one-time password for ${
        purpose === 'password-reset' ? 'password reset' : 'account registration verification'
      } is:</p>
      <p style="font-size:24px;font-weight:bold;letter-spacing:4px">${otpCode}</p>
      <p>This code expires in 10 minutes.</p>
    </div>
  `;

  await transporter.sendMail({
    from: fromAddress,
    to,
    subject,
    html,
  });
}

async function sendNotificationEmail({ to, subject, title, message }) {
  try {
    const transporter = createTransport();
    if (!transporter) {
      console.log(`[Email Service Notification Mock] ${subject} to ${to}: ${message}`);
      return;
    }

    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#2563eb">${title}</h2>
        <p>${message}</p>
        <hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0" />
        <p style="font-size:12px;color:#6b7280">This is an automated notification from Ekota Platform.</p>
      </div>
    `;

    await transporter.sendMail({
      from: fromAddress,
      to,
      subject,
      html,
    });
  } catch (err) {
    console.error('[Email Service Error]', err.message);
  }
}

module.exports = { sendOtpEmail, sendNotificationEmail };