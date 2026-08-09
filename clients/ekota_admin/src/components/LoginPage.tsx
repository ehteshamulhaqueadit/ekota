import { FormEvent, useMemo, useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { apiRequest } from '../lib/api';
import type {
  AuthMode,
  AuthSession,
  LoginPayload,
  RequestPasswordResetPayload,
  ResetPasswordPayload,
  SignupPayload,
  VerifyRegistrationPayload,
} from '../types/auth';

interface LoginPageProps {
  onAuthenticated: (session: AuthSession) => void;
}

const roles = ['ADMIN', 'RENTER', 'INVESTOR', 'PRODUCER'] as const;

type AuthFormState = {
  email: string;
  password: string;
  fullName: string;
  phoneNumber: string;
  role: string;
  otpCode: string;
  newPassword: string;
};

const initialForm: AuthFormState = {
  email: '',
  password: '',
  fullName: '',
  phoneNumber: '',
  role: 'ADMIN',
  otpCode: '',
  newPassword: '',
};

export default function LoginPage({ onAuthenticated }: LoginPageProps) {
  const navigate = useNavigate();
  const location = useLocation();

  const mode = useMemo<AuthMode>(() => {
    switch (location.pathname) {
      case '/signup': return 'signup';
      case '/verify': return 'verify';
      case '/forgot-password': return 'reset-request';
      case '/reset-password': return 'reset-password';
      default: return 'login';
    }
  }, [location.pathname]);

  const [form, setForm] = useState<AuthFormState>(initialForm);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Clear messages when mode changes
  useEffect(() => {
    setError('');
    setSuccess('');
  }, [mode]);

  const canSubmit = useMemo(() => {
    const email = form.email.trim();

    switch (mode) {
      case 'login':
        return email.length > 0 && form.password.trim().length > 0;
      case 'signup':
        return (
          email.length > 0 &&
          form.password.trim().length > 0 &&
          form.fullName.trim().length > 0 &&
          form.role.trim().length > 0
        );
      case 'verify':
        return email.length > 0 && form.otpCode.trim().length > 0;
      case 'reset-request':
        return email.length > 0;
      case 'reset-password':
        return (
          email.length > 0 &&
          form.otpCode.trim().length > 0 &&
          form.newPassword.trim().length > 0
        );
      default:
        return false;
    }
  }, [form.email, form.fullName, form.newPassword, form.otpCode, form.password, form.role, mode]);

  const title = {
    login: 'Sign in to continue',
    signup: 'Create an account',
    verify: 'Verify registration',
    'reset-request': 'Request password reset',
    'reset-password': 'Reset your password',
  }[mode];

  const lead = {
    login: 'Use your Ekota account to access the admin workspace.',
    signup: 'Register a new account and verify it with the OTP sent to email.',
    verify: 'Confirm the OTP sent during registration to activate the account.',
    'reset-request': 'Send a password reset OTP to the email on file.',
    'reset-password': 'Use the reset OTP and a new password to regain access.',
  }[mode];

  function switchMode(nextMode: AuthMode) {
    switch (nextMode) {
      case 'signup': navigate('/signup'); break;
      case 'verify': navigate('/verify'); break;
      case 'reset-request': navigate('/forgot-password'); break;
      case 'reset-password': navigate('/reset-password'); break;
      default: navigate('/login'); break;
    }
  }

  function updateField<K extends keyof AuthFormState>(key: K, value: AuthFormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function handleLogin() {
    const payload: LoginPayload = {
      email: form.email.trim(),
      password: form.password,
    };

    const session = (await apiRequest('/auth/login', {
      method: 'POST',
      body: JSON.stringify(payload),
    })) as AuthSession;

    localStorage.setItem('ekota_admin_session', JSON.stringify(session));
    onAuthenticated(session);
  }

  async function handleSignup() {
    const payload: SignupPayload = {
      email: form.email.trim(),
      password: form.password,
      fullName: form.fullName.trim(),
      phoneNumber: form.phoneNumber.trim(),
      role: form.role,
    };

    const response = (await apiRequest('/auth/signup', {
      method: 'POST',
      body: JSON.stringify(payload),
    })) as { message?: string; verificationRequired?: boolean; user?: { email?: string } };

    setSuccess(response.message || 'Account created. Verify the OTP sent to email.');
    setForm((prev) => ({ ...prev, otpCode: '', newPassword: '' }));
    navigate('/verify');
  }

  async function handleVerify() {
    const payload: VerifyRegistrationPayload = {
      email: form.email.trim(),
      otpCode: form.otpCode.trim(),
    };

    const response = (await apiRequest('/auth/registration/confirm', {
      method: 'POST',
      body: JSON.stringify(payload),
    })) as { message?: string };

    setSuccess(response.message || 'Email verified successfully. You can sign in now.');
    navigate('/login');
  }

  async function handleResendVerification() {
    const email = form.email.trim();

    if (!email) {
      throw new Error('Email is required');
    }

    const response = (await apiRequest('/auth/registration/request-verification', {
      method: 'POST',
      body: JSON.stringify({ email }),
    })) as { message?: string };

    setSuccess(response.message || 'Verification OTP sent successfully.');
  }

  async function handleResetRequest() {
    const payload: RequestPasswordResetPayload = {
      email: form.email.trim(),
    };

    const response = (await apiRequest('/auth/password-reset/request', {
      method: 'POST',
      body: JSON.stringify(payload),
    })) as { message?: string };

    setSuccess(response.message || 'If the account exists, a reset OTP has been sent.');
    navigate('/reset-password');
  }

  async function handleResetPassword() {
    const payload: ResetPasswordPayload = {
      email: form.email.trim(),
      otpCode: form.otpCode.trim(),
      newPassword: form.newPassword,
    };

    const response = (await apiRequest('/auth/password-reset/reset-password', {
      method: 'POST',
      body: JSON.stringify(payload),
    })) as { message?: string };

    setSuccess(response.message || 'Password reset successful. Sign in with your new password.');
    navigate('/login');
  }

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError('');
    setSuccess('');
    setIsSubmitting(true);

    try {
      if (mode === 'login') {
        await handleLogin();
      } else if (mode === 'signup') {
        await handleSignup();
      } else if (mode === 'verify') {
        await handleVerify();
      } else if (mode === 'reset-request') {
        await handleResetRequest();
      } else {
        await handleResetPassword();
      }
    } catch (err: any) {
      // Catch specific backend error format and auto-redirect if unverified
      if (err.message && err.message.toLowerCase().includes('not verified')) {
        navigate('/verify');
      } else {
        setError(err instanceof Error ? err.message : 'Login failed');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <p className="eyebrow">Ekota Admin</p>
        <h1>{title}</h1>
        <p className="lede">{lead}</p>


        <form onSubmit={handleSubmit} className="auth-form">
          <label>
            Email
            <input
              type="email"
              value={form.email}
              onChange={(event) => updateField('email', event.target.value)}
              placeholder="you@example.com"
              required
            />
          </label>

          {mode === 'signup' ? (
            <>
              <label>
                Full name
                <input
                  type="text"
                  value={form.fullName}
                  onChange={(event) => updateField('fullName', event.target.value)}
                  placeholder="Amina Rahman"
                  required
                />
              </label>

              <label>
                Phone number
                <input
                  type="tel"
                  value={form.phoneNumber}
                  onChange={(event) => updateField('phoneNumber', event.target.value)}
                  placeholder="01700000000"
                />
              </label>

              <label>
                Role
                <select value={form.role} onChange={(event) => updateField('role', event.target.value)}>
                  {roles.map((role) => (
                    <option key={role} value={role}>{role}</option>
                  ))}
                </select>
              </label>
            </>
          ) : null}

          {mode === 'login' || mode === 'signup' ? (
            <label>
              Password
              <input
                type="password"
                value={form.password}
                onChange={(event) => updateField('password', event.target.value)}
                placeholder="••••••••"
                required
              />
            </label>
          ) : null}

          {mode === 'reset-password' ? (
            <label>
              New password
              <input
                type="password"
                value={form.newPassword}
                onChange={(event) => updateField('newPassword', event.target.value)}
                placeholder="Enter a new password"
                required
              />
            </label>
          ) : null}

          {mode === 'verify' || mode === 'reset-password' ? (
            <label>
              OTP code
              <input
                type="text"
                value={form.otpCode}
                onChange={(event) => updateField('otpCode', event.target.value)}
                placeholder="123456"
                inputMode="numeric"
                required
              />
            </label>
          ) : null}

          {error ? <p className="auth-error">{error}</p> : null}
          {success ? <p className="auth-success">{success}</p> : null}

          <button type="submit" disabled={!canSubmit || isSubmitting}>
            {isSubmitting
              ? 'Submitting…'
              : mode === 'login'
                ? 'Sign in'
                : mode === 'signup'
                  ? 'Create account'
                  : mode === 'verify'
                    ? 'Verify email'
                    : mode === 'reset-request'
                      ? 'Send reset OTP'
                      : 'Reset password'}
          </button>

          <div className="auth-links" style={{ display: 'flex', justifyContent: 'space-between', marginTop: '1rem' }}>
            {mode === 'login' ? (
              <>
                <button type="button" className="link-button" onClick={() => switchMode('reset-request')}>Forgot Password?</button>
                <button type="button" className="link-button" onClick={() => switchMode('signup')}>Sign up</button>
              </>
            ) : mode === 'signup' ? (
              <button type="button" className="link-button" style={{ width: '100%', textAlign: 'center' }} onClick={() => switchMode('login')}>Already have an account? Sign in</button>
            ) : mode === 'reset-request' || mode === 'reset-password' ? (
              <button type="button" className="link-button" style={{ width: '100%', textAlign: 'center' }} onClick={() => switchMode('login')}>Back to sign in</button>
            ) : mode === 'verify' ? (
              <>
                <button type="button" className="link-button" onClick={() => switchMode('login')}>Back to sign in</button>
                <button type="button" className="link-button" onClick={() => handleResendVerification()}>Resend OTP</button>
              </>
            ) : null}
          </div>
        </form>
      </section>
    </main>
  );
}
