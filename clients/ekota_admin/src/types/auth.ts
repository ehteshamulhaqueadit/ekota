export interface LoginPayload {
  email: string;
  password: string;
}

export interface SignupPayload {
  email: string;
  password: string;
  fullName: string;
  phoneNumber: string;
  role: string;
}

export interface VerifyRegistrationPayload {
  email: string;
  otpCode: string;
}

export interface RequestPasswordResetPayload {
  email: string;
}

export interface ResetPasswordPayload {
  email: string;
  otpCode: string;
  newPassword: string;
}

export interface AuthUser {
  id: string;
  email: string;
  fullName: string;
  role: string;
}

export interface AuthSession {
  user: AuthUser;
  token: string;
}

export type AuthMode = 'login' | 'signup' | 'verify' | 'reset-request' | 'reset-password';
