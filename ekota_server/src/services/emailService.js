const nodemailer = require('nodemailer');

function createTransport() {
  const gmailUser = process.env.GMAIL_USER;
  const gmailAppPassword = process.env.GMAIL_APP_PASSWORD;

  if (!gmailUser || !gmailAppPassword) {
    throw new Error('GMAIL_USER and GMAIL_APP_PASSWORD are required');
  }

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: gmailUser,
      pass: gmailAppPassword
    },
    connectionTimeout: 15000,
    greetingTimeout: 15000,
    socketTimeout: 15000
  });
}

async function sendOtpEmail({ to, otpCode, purpose }) {
  const transporter = createTransport();
  const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;

  const subject = purpose === 'password-reset'
    ? 'Ekota password reset OTP'
    : 'Ekota account verification OTP';

  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.6">
      <h2>Ekota OTP Code</h2>
      <p>Your one-time password for ${purpose === 'password-reset' ? 'password reset' : 'account registration verification'} is:</p>
      <p style="font-size:24px;font-weight:bold;letter-spacing:4px">${otpCode}</p>
      <p>This code expires in 10 minutes.</p>
    </div>
  `;

  await transporter.sendMail({
    from: fromAddress,
    to,
    subject,
    html
  });
}

module.exports = { sendOtpEmail };