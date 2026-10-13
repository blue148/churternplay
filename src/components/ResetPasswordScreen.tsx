import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { BookOpen } from 'lucide-react';

interface ResetPasswordScreenProps {
  onDone: () => void;
}

export default function ResetPasswordScreen({ onDone }: ResetPasswordScreenProps) {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      onDone();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

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
              Set New Password
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label htmlFor="newPassword" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                New Password
              </label>
              <input
                id="newPassword"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                required
                minLength={6}
                autoComplete="new-password"
              />
            </div>

            <div>
              <label htmlFor="confirmPassword" className="block text-xs font-body text-slate-500 uppercase tracking-wider mb-2">
                Confirm Password
              </label>
              <input
                id="confirmPassword"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full px-4 py-3 bg-cream border thin-rule rule-line input-radius focus:outline-none focus:bg-white transition font-body text-sm"
                required
                minLength={6}
                autoComplete="new-password"
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
              {loading ? 'Saving...' : 'Update Password'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
