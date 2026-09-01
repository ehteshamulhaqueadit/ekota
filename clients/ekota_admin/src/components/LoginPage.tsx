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

    if (!session || !session.user || session.user.role !== 'ADMIN') {
      throw new Error('Access denied: Only system administrators can access this portal.');
    }

    sessionStorage.setItem('ekota_admin_session', JSON.stringify(session));
    onAuthenticated(session);
  }

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError('');
    setSuccess('');
    setIsSubmitting(true);

    try {
      await handleLogin();
    } catch (err: any) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="auth-shell">
      <section className="auth-card">
        <p className="eyebrow">Ekota Admin</p>
        <h1>Sign in to continue</h1>
        <p className="lede">Use your verified Ekota Admin credentials to access the portal.</p>

        <form onSubmit={handleSubmit} className="auth-form">
          <label>
            Email
            <input
              type="email"
              value={form.email}
              onChange={(event) => updateField('email', event.target.value)}
              placeholder="admin@ekota.com"
              required
            />
          </label>

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

          {error ? <p className="auth-error">{error}</p> : null}

          <button type="submit" disabled={!canSubmit || isSubmitting}>
            {isSubmitting ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
      </section>
    </main>
  );
}
