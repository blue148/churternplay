import { useState } from 'react';
import { requestPasswordReset, signIn, signUp } from '../lib/auth';
import { BookOpen } from 'lucide-react';

interface AuthFormProps {
  onSuccess: () => void;
}

export default function AuthForm({ onSuccess }: AuthFormProps) {
  const [isSignUp, setIsSignUp] = useState(false);
  const [isForgotPassword, setIsForgotPassword] = useState(false);
  const [email, setEmail] = useState('');
  const [loginId, setLoginId] = useState('');
  const [resetId, setResetId] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [phone, setPhone] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [resetSent, setResetSent] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (isSignUp) {
        if (!username) {
          setError('Username is required');
          setLoading(false);
          return;
        }
        await signUp(email, password, username, phone.trim() || undefined);
      } else {
        await signIn(loginId, password);
      }
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const handleResetSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await requestPasswordReset(resetId);
      setResetSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const backToSignIn = () => {
    setIsForgotPassword(false);
    setResetSent(false);
    setResetId('');
    setError('');
  };

  if (isForgotPassword) {
    return (
      <div className="min-h-screen bg-cream flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <div className="bg-cream linen-texture border thin-rule rule-line container-radius p-12">
            <div className="flex flex-col items-center mb-12">
              <BookOpen className="w-12 h-12 text-terracotta-600 mb-6" strokeWidth={1.5} />
              <h1 className="text-4xl font-display font-light text-slate-900 tracking-wide text-center">
                Churtern•Play
              </h1>
              <div className="h-px w-16 bg-slate-300 mt-4 mb-2" />
              <p className="text-xs font-body text-slate-500 tracking-widest text-center">
                Reset Password
              </p>
            </div>

            {resetSent ? (
              <div className="space-y-6">
                <div className="bg-slate-50 border thin-rule rule-line text-slate-700 px-4 py-3 text-sm font-body input-radius">
                  If an account exists for that email or phone, a reset link has been sent. Check your inbox.
                </div>
                <button
                  onClick={backToSignIn}
                  className="w-full bg-slate-900 text-cream py-3 font-body text-sm uppercase tracking-widest hover:bg-slate-800 transition input-radius"
                >
                  Return to Sign In
                </button>
              </div>
            ) : (
              <form onSubmit={handleResetSubmit} className="space-y-6">
                <div>
                  <label htmlFor="resetId" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                    Email or Phone
                  </label>
                  <input
                    id="resetId"
                    type="text"
                    value={resetId}
                    onChange={(e) => setResetId(e.target.value)}
                    className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                    required
                    autoComplete="username"
                  />
                </div>

                {error && (
                  <div className="bg-terracotta-50 border thin-rule border-terracotta-300 text-terracotta-900 px-4 py-3 text-sm font-body input-radius">
                    {error}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full bg-slate-900 text-cream py-3 font-body text-sm uppercase tracking-widest hover:bg-slate-800 transition disabled:opacity-50 disabled:cursor-not-allowed input-radius"
                >
                  {loading ? 'Sending...' : 'Send Reset Link'}
                </button>
              </form>
            )}

            <div className="mt-8 pt-6 border-t thin-rule rule-line text-center">
              <button
                onClick={backToSignIn}
                className="text-xs font-body text-slate-600 hover:text-slate-900 uppercase tracking-wider transition"
              >
                Return to Sign In
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-cream flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="bg-cream linen-texture border thin-rule rule-line container-radius p-12">
          <div className="flex flex-col items-center mb-12">
            <BookOpen className="w-12 h-12 text-terracotta-600 mb-6" strokeWidth={1.5} />
            <h1 className="text-4xl font-display font-light text-slate-900 tracking-wide text-center">
              Churtern•Play
            </h1>
            <div className="h-px w-16 bg-slate-300 mt-4 mb-2" />
            <p className="text-xs font-body text-slate-500 tracking-widest text-center">
              {isSignUp ? 'Registration' : 'Authentication'}
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            {isSignUp && (
              <div>
                <label htmlFor="username" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                  Username
                </label>
                <input
                  id="username"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                  required={isSignUp}
                  autoComplete="username"
                />
              </div>
            )}

            {isSignUp ? (
              <div>
                <label htmlFor="email" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                  Email
                </label>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                  required
                  autoComplete="email"
                />
              </div>
            ) : (
              <div>
                <label htmlFor="loginId" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                  Email or Phone
                </label>
                <input
                  id="loginId"
                  type="text"
                  value={loginId}
                  onChange={(e) => setLoginId(e.target.value)}
                  className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                  required
                  autoComplete="username"
                />
              </div>
            )}

            {isSignUp && (
              <div>
                <label htmlFor="phone" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                  Phone <span className="normal-case text-slate-400">(optional)</span>
                </label>
                <input
                  id="phone"
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                  autoComplete="tel"
                  placeholder="+1 555 123 4567"
                />
              </div>
            )}

            <div>
              <label htmlFor="password" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                Password
              </label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                required
                minLength={6}
                autoComplete={isSignUp ? 'new-password' : 'current-password'}
              />
              {!isSignUp && (
                <button
                  type="button"
                  onClick={() => {
                    setIsForgotPassword(true);
                    setResetId(loginId);
                    setError('');
                  }}
                  className="mt-2 text-xs font-body text-slate-500 hover:text-slate-800 transition"
                >
                  Forgot password?
                </button>
              )}
            </div>

            {error && (
              <div className="bg-terracotta-50 border thin-rule border-terracotta-300 text-terracotta-900 px-4 py-3 text-sm font-body input-radius">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-slate-900 text-cream py-3 font-body text-sm uppercase tracking-widest hover:bg-slate-800 transition disabled:opacity-50 disabled:cursor-not-allowed input-radius"
            >
              {loading ? 'Processing...' : isSignUp ? 'Register' : 'Enter'}
            </button>
          </form>

          <div className="mt-8 pt-6 border-t thin-rule rule-line text-center">
            <button
              onClick={() => {
                setIsSignUp(!isSignUp);
                setError('');
              }}
              className="text-xs font-body text-slate-600 hover:text-slate-900 uppercase tracking-wider transition"
            >
              {isSignUp ? 'Return to Sign In' : 'Create New Account'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
