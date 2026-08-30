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
    }
  });
}

async function sendOtpEmail({ to, otpCode, purpose }) {
  try {
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
  } catch (err) {
    console.warn('[EmailService] Failed to send OTP email:', err.message);
  }
}

async function sendAccountBlockedEmail({ to, fullName, reason }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;

    const subject = 'Ekota Platform - Account Temporarily Blocked';
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#d9534f">Account Blocked / Frozen</h2>
        <p>Hello ${fullName || 'User'},</p>
        <p>Your account on Ekota has been <strong>temporarily blocked</strong> by an administrator.</p>
        <div style="background:#f8d7da;border-left:4px solid #d9534f;padding:12px;margin:16px 0;border-radius:4px">
          <strong>Reason specified by Admin:</strong>
          <p style="margin:8px 0 0 0">${reason || 'Violation of platform community guidelines.'}</p>
        </div>
        <p>Your account will remain frozen until you submit an appeal and prove innocence to the administration.</p>
        <p>If you believe this is a mistake, please reply to this email or contact platform support.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Administration Team</p>
      </div>
    `;

    await transporter.sendMail({
      from: fromAddress,
      to,
      subject,
      html
    });
  } catch (err) {
    console.warn('[EmailService] Failed to send account blocked email:', err.message);
  }
}

async function sendAccountUnblockedEmail({ to, fullName }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;

    const subject = 'Ekota Platform - Account Access Restored';
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#5cb85c">Account Unblocked</h2>
        <p>Hello ${fullName || 'User'},</p>
        <p>We are pleased to inform you that your Ekota account has been <strong>unblocked and restored</strong>.</p>
        <p>You can now log in and use all features of the platform as normal.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Administration Team</p>
      </div>
    `;

    await transporter.sendMail({
      from: fromAddress,
      to,
      subject,
      html
    });
  } catch (err) {
    console.warn('[EmailService] Failed to send account unblocked email:', err.message);
  }
}

async function sendProducerWarningEmail({ to, fullName, postTitle, reason }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;

    const subject = `Ekota Admin Notice - Action required regarding your post "${postTitle || 'Listing'}"`;
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#f0ad4e">Official Notice Regarding Your Post</h2>
        <p>Hello ${fullName || 'Producer'},</p>
        <p>An administrator has reviewed your post <strong>"${postTitle || 'Listing'}"</strong> and issued the following notice:</p>
        <div style="background:#fcf8e3;border-left:4px solid #f0ad4e;padding:12px;margin:16px 0;border-radius:4px">
          <strong>Notice / Issue Description:</strong>
          <p style="margin:8px 0 0 0">${reason}</p>
        </div>
        <p>Please update or fix your post according to platform guidelines to avoid further action or account suspension.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Administration Team</p>
      </div>
    `;

    await transporter.sendMail({
      from: fromAddress,
      to,
      subject,
      html
    });
  } catch (err) {
    console.warn('[EmailService] Failed to send producer warning email:', err.message);
  }
}

async function sendWithdrawalApprovedEmail({ to, fullName, amount, method, adminNote }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;
    const subject = 'Ekota Payout Withdrawal Approved';
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#047857">Withdrawal Request Approved</h2>
        <p>Hello ${fullName || 'Producer'},</p>
        <p>Your withdrawal request for <strong>৳${Number(amount).toLocaleString('en-BD')} BDT</strong> via <strong>${method}</strong> has been <strong>approved</strong> by Ekota administration.</p>
        ${adminNote ? `<p><strong>Admin Note:</strong> ${adminNote}</p>` : ''}
        <p>The funds are being transferred to your registered account.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Financial Operations</p>
      </div>
    `;
    await transporter.sendMail({ from: fromAddress, to, subject, html });
  } catch (err) {
    console.warn('[EmailService] Failed to send withdrawal approved email:', err.message);
  }
}

async function sendWithdrawalRejectedEmail({ to, fullName, amount, method, reason }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;
    const subject = 'Ekota Payout Withdrawal Request Update';
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#dc2626">Withdrawal Request Rejected</h2>
        <p>Hello ${fullName || 'Producer'},</p>
        <p>Your withdrawal request for <strong>৳${Number(amount).toLocaleString('en-BD')} BDT</strong> via <strong>${method}</strong> was not approved at this time.</p>
        <div style="background:#fee2e2;border-left:4px solid #dc2626;padding:12px;margin:16px 0;border-radius:4px">
          <strong>Reason specified by Admin:</strong>
          <p style="margin:8px 0 0 0">${reason || 'Verification check required.'}</p>
        </div>
        <p>The requested amount has been restored to your available wallet balance.</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Financial Operations</p>
      </div>
    `;
    await transporter.sendMail({ from: fromAddress, to, subject, html });
  } catch (err) {
    console.warn('[EmailService] Failed to send withdrawal rejected email:', err.message);
  }
}

async function sendPaymentSuccessEmail({ to, fullName, amount, tranId, paymentType }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;
    const subject = 'Ekota Payment Confirmation - Transaction Successful';
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#047857">Payment Verified & Validated</h2>
        <p>Hello ${fullName || 'Customer'},</p>
        <p>Your payment of <strong>৳${Number(amount).toLocaleString('en-BD')} BDT</strong> (${paymentType}) via SSLCommerz has been successfully processed and verified.</p>
        <p><strong>Transaction ID:</strong> ${tranId}</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Accounts & Billing</p>
      </div>
    `;
    await transporter.sendMail({ from: fromAddress, to, subject, html });
  } catch (err) {
    console.warn('[EmailService] Failed to send payment success email:', err.message);
  }
}

async function sendPaymentFailedEmail({ to, fullName, amount, tranId, reason }) {
  try {
    const transporter = createTransport();
    const fromAddress = process.env.GMAIL_FROM || process.env.GMAIL_USER;
    const subject = 'Ekota Payment Notice - Transaction Unsuccessful';
    const html = `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333">
        <h2 style="color:#dc2626">Payment Processing Failed</h2>
        <p>Hello ${fullName || 'Customer'},</p>
        <p>Your payment attempt of <strong>৳${Number(amount).toLocaleString('en-BD')} BDT</strong> (Tran ID: ${tranId}) could not be completed.</p>
        <p><strong>Reason:</strong> ${reason || 'Transaction cancelled or declined by gateway.'}</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0" />
        <p style="font-size:12px;color:#777">Ekota Accounts & Billing</p>
      </div>
    `;
    await transporter.sendMail({ from: fromAddress, to, subject, html });
  } catch (err) {
    console.warn('[EmailService] Failed to send payment failed email:', err.message);
  }
}

module.exports = {
  sendOtpEmail,
  sendAccountBlockedEmail,
  sendAccountUnblockedEmail,
  sendProducerWarningEmail,
  sendWithdrawalApprovedEmail,
  sendWithdrawalRejectedEmail,
  sendPaymentSuccessEmail,
  sendPaymentFailedEmail
};