import { useState, useEffect, useRef } from 'react';
import { X, User, Mail, Phone, FileText, Lock, Upload, Check, LogOut, ChevronDown, ChevronUp, Trash2, AlertTriangle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';

interface ProfileDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  mode?: 'drawer' | 'page';
}

const PREDEFINED_AVATARS = [
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Aneka',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Max',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Sophie',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Charlie',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Luna',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Oliver',
  'https://api.dicebear.com/7.x/avataaars/svg?seed=Bella',
];

export default function ProfileDrawer({ isOpen, onClose, mode = 'drawer' }: ProfileDrawerProps) {
  const { profile, user, refreshProfile, signOut } = useAuth();
  const [username, setUsername] = useState('');
  const [phone, setPhone] = useState('');
  const [bio, setBio] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [error, setError] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [success, setSuccess] = useState(false);
  const [passwordSuccess, setPasswordSuccess] = useState(false);
  const [passwordSectionOpen, setPasswordSectionOpen] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (profile) {
      setUsername(profile.username || '');
      setPhone(profile.phone || '');
      setBio(profile.bio || '');
      setAvatarUrl(profile.avatar_url || '');
    }
  }, [profile]);

  useEffect(() => {
    if (!isOpen) {
      setError('');
      setPasswordError('');
      setSuccess(false);
      setPasswordSuccess(false);
      setPasswordSectionOpen(false);
      setNewPassword('');
      setConfirmPassword('');
      setDeleteConfirmOpen(false);
      setDeleteError('');
    }
  }, [isOpen]);

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0] || !user) return;

    const file = e.target.files[0];

    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) {
      setError('Please upload a JPG, PNG, WebP, or GIF image');
      return;
    }

    if (file.size > 2 * 1024 * 1024) {
      setError('Image size must be less than 2MB');
      return;
    }

    setUploadingAvatar(true);
    setError('');

    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `${user.id}/avatar-${Date.now()}.${fileExt}`;

      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(fileName, file, { upsert: true });

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('avatars')
        .getPublicUrl(fileName);

      setAvatarUrl(publicUrl);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to upload avatar');
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess(false);

    if (newPassword.length < 6) {
      setPasswordError('Password must be at least 6 characters');
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('Passwords do not match');
      return;
    }

    setPasswordLoading(true);

    try {
      const { error: updateError } = await supabase.auth.updateUser({ password: newPassword });
      if (updateError) throw updateError;

      setPasswordSuccess(true);
      setNewPassword('');
      setConfirmPassword('');
      setTimeout(() => setPasswordSuccess(false), 3000);
    } catch (err) {
      setPasswordError(err instanceof Error ? err.message : 'Failed to update password');
    } finally {
      setPasswordLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setLoading(true);
    setError('');
    setSuccess(false);

    try {
      const { error: updateError } = await supabase
        .from('profiles')
        .update({
          username: username.trim(),
          phone: phone.trim() || null,
          bio: bio.trim(),
          avatar_url: avatarUrl.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', user.id);

      if (updateError) throw updateError;

      await refreshProfile();
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  const handleSignOut = async () => {
    onClose();
    await signOut();
  };

  const handleDeleteAccount = async () => {
    setDeleting(true);
    setDeleteError('');

    try {
      const { error: deleteErr } = await supabase.functions.invoke('delete-account');
      if (deleteErr) throw deleteErr;

      onClose();
      await signOut();
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : 'Failed to delete account. Please try again.');
      setDeleting(false);
    }
  };

  if (mode !== 'page' && !isOpen) return null;

  const innerContent = (
    <div className={mode === 'page' ? 'flex-1' : 'flex-1 overflow-y-auto'}>

          <div className="px-6 py-6 border-b thin-rule rule-line">
            <div className="flex items-center gap-4">
              <div className="relative flex-shrink-0">
                {avatarUrl ? (
                  <img
                    src={avatarUrl}
                    alt={username}
                    className="w-16 h-16 rounded-full object-cover border thin-rule rule-line"
                  />
                ) : (
                  <div className="w-16 h-16 rounded-full bg-slate-200 border thin-rule rule-line flex items-center justify-center">
                    <span className="text-xl font-display font-light text-slate-600">
                      {username?.charAt(0).toUpperCase()}
                    </span>
                  </div>
                )}
              </div>
              <div className="min-w-0">
                <p className="text-lg font-display font-light text-slate-900 truncate">{username}</p>
                <p className="text-sm font-body text-slate-500 truncate">{profile?.email}</p>
                {profile?.total_games !== undefined && (
                  <p className="text-xs font-body text-slate-400 mt-0.5">
                    {profile.total_games} {profile.total_games === 1 ? 'game' : 'games'} in library
                  </p>
                )}
              </div>
            </div>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="px-6 pt-6 pb-4 space-y-5">

              <div>
                <label className="flex items-center gap-2 text-xs font-body text-slate-500 tracking-wider mb-2">
                  <Mail className="w-3.5 h-3.5" strokeWidth={1.5} />
                  Email
                </label>
                <input
                  type="email"
                  value={profile?.email || ''}
                  disabled
                  className="w-full px-4 py-2.5 border thin-rule rule-line bg-slate-50 text-slate-400 font-body text-sm cursor-not-allowed"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-xs font-body text-slate-500 tracking-wider mb-2">
                  <User className="w-3.5 h-3.5" strokeWidth={1.5} />
                  Username
                </label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="Your username"
                  required
                  maxLength={50}
                  className="w-full px-4 py-2.5 border thin-rule rule-line bg-white text-slate-900 font-body text-sm focus:outline-none focus:border-slate-400 transition-colors"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-xs font-body text-slate-500 tracking-wider mb-2">
                  <Phone className="w-3.5 h-3.5" strokeWidth={1.5} />
                  Phone <span className="normal-case text-slate-400">(optional)</span>
                </label>
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+1 555 123 4567"
                  className="w-full px-4 py-2.5 border thin-rule rule-line bg-white text-slate-900 font-body text-sm focus:outline-none focus:border-slate-400 transition-colors"
                />
                <p className="mt-1 text-xs font-body text-slate-400">Used as a secondary contact method, not for sign-in</p>
              </div>

              <div>
                <label className="flex items-center gap-2 text-xs font-body text-slate-500 tracking-wider mb-3">
                  <User className="w-3.5 h-3.5" strokeWidth={1.5} />
                  Avatar
                </label>

                <div className="flex items-center gap-4 mb-4">
                  <div className="flex-shrink-0">
                    {avatarUrl ? (
                      <img
                        src={avatarUrl}
                        alt="Current avatar"
                        className="w-14 h-14 rounded-full object-cover border thin-rule rule-line"
                      />
                    ) : (
                      <div className="w-14 h-14 rounded-full bg-slate-100 border thin-rule rule-line flex items-center justify-center">
                        <User className="w-6 h-6 text-slate-400" strokeWidth={1.5} />
                      </div>
                    )}
                  </div>
                  <div>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      onChange={handleAvatarUpload}
                      className="hidden"
                    />
                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={uploadingAvatar}
                      className="flex items-center gap-2 px-4 py-2 border thin-rule rule-line text-sm font-body text-slate-700 hover:bg-slate-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <Upload className="w-4 h-4" strokeWidth={1.5} />
                      {uploadingAvatar ? 'Uploading...' : 'Upload Photo'}
                    </button>
                    <p className="mt-1.5 text-xs font-body text-slate-400">Max 2MB · JPG, PNG, WebP, or GIF</p>
                  </div>
                </div>

                <p className="text-xs font-body text-slate-500 mb-2">Or choose a preset:</p>
                <div className="grid grid-cols-8 gap-2">
                  {PREDEFINED_AVATARS.map((avatar, index) => (
                    <button
                      key={index}
                      type="button"
                      onClick={() => setAvatarUrl(avatar)}
                      className={`relative aspect-square rounded-full overflow-hidden border-2 transition-all hover:scale-105 ${
                        avatarUrl === avatar
                          ? 'border-slate-900 ring-1 ring-slate-900 ring-offset-1'
                          : 'border-slate-200 hover:border-slate-400'
                      }`}
                    >
                      <img src={avatar} alt={`Avatar ${index + 1}`} className="w-full h-full object-cover" />
                      {avatarUrl === avatar && (
                        <div className="absolute inset-0 bg-slate-900/40 flex items-center justify-center">
                          <Check className="w-3 h-3 text-white" strokeWidth={2.5} />
                        </div>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="flex items-center gap-2 text-xs font-body text-slate-500 tracking-wider mb-2">
                  <FileText className="w-3.5 h-3.5" strokeWidth={1.5} />
                  Bio
                </label>
                <textarea
                  value={bio}
                  onChange={(e) => setBio(e.target.value)}
                  placeholder="Tell us about yourself..."
                  rows={3}
                  maxLength={500}
                  className="w-full px-4 py-2.5 border thin-rule rule-line bg-white text-slate-900 font-body text-sm focus:outline-none focus:border-slate-400 transition-colors resize-none"
                />
                <p className="mt-1 text-xs font-body text-slate-400 text-right">{bio.length}/500</p>
              </div>

              {error && (
                <div className="px-4 py-3 bg-red-50 border border-red-100">
                  <p className="text-sm font-body text-red-600">{error}</p>
                </div>
              )}

              {success && (
                <div className="px-4 py-3 bg-green-50 border border-green-100">
                  <p className="text-sm font-body text-green-700">Profile updated successfully.</p>
                </div>
              )}

              <div className="flex gap-3 pt-1">
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 py-2.5 bg-slate-900 text-cream font-body text-sm hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? 'Saving...' : 'Save Changes'}
                </button>
                <button
                  type="button"
                  onClick={onClose}
                  className="px-5 py-2.5 border thin-rule rule-line font-body text-sm text-slate-700 hover:bg-slate-50 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          </form>

          <div className="px-6 pb-4 border-t thin-rule rule-line">
            <button
              type="button"
              onClick={() => setPasswordSectionOpen(!passwordSectionOpen)}
              className="w-full flex items-center justify-between py-4 text-left"
            >
              <span className="flex items-center gap-2 text-xs font-body text-slate-500 tracking-wider">
                <Lock className="w-3.5 h-3.5" strokeWidth={1.5} />
                Change Password
              </span>
              {passwordSectionOpen
                ? <ChevronUp className="w-4 h-4 text-slate-400" strokeWidth={1.5} />
                : <ChevronDown className="w-4 h-4 text-slate-400" strokeWidth={1.5} />
              }
            </button>

            {passwordSectionOpen && (
              <form onSubmit={handlePasswordChange} className="space-y-4 pb-4">
                <div>
                  <label className="block text-xs font-body text-slate-500 tracking-wider mb-2">New Password</label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Minimum 6 characters"
                    minLength={6}
                    className="w-full px-4 py-2.5 border thin-rule rule-line bg-white text-slate-900 font-body text-sm focus:outline-none focus:border-slate-400 transition-colors"
                  />
                </div>

                <div>
                  <label className="block text-xs font-body text-slate-500 tracking-wider mb-2">Confirm Password</label>
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Re-enter new password"
                    minLength={6}
                    className="w-full px-4 py-2.5 border thin-rule rule-line bg-white text-slate-900 font-body text-sm focus:outline-none focus:border-slate-400 transition-colors"
                  />
                </div>

                {passwordError && (
                  <div className="px-4 py-3 bg-red-50 border border-red-100">
                    <p className="text-sm font-body text-red-600">{passwordError}</p>
                  </div>
                )}

                {passwordSuccess && (
                  <div className="px-4 py-3 bg-green-50 border border-green-100">
                    <p className="text-sm font-body text-green-700">Password updated successfully.</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={passwordLoading || !newPassword || !confirmPassword}
                  className="w-full py-2.5 bg-slate-900 text-cream font-body text-sm hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {passwordLoading ? 'Updating...' : 'Update Password'}
                </button>
              </form>
            )}
          </div>

          <div className="px-6 pb-6 border-t thin-rule rule-line pt-4">
            <button
              type="button"
              onClick={() => setDeleteConfirmOpen(true)}
              className="w-full flex items-center gap-2 text-xs font-body text-terracotta-700 tracking-wider hover:text-terracotta-900 transition-colors"
            >
              <Trash2 className="w-3.5 h-3.5" strokeWidth={1.5} />
              Delete Account
            </button>
          </div>
    </div>
  );

  const footer = (
    <div className="flex-shrink-0 px-6 py-4 border-t thin-rule rule-line">
      <button
        onClick={handleSignOut}
        className="w-full flex items-center justify-center gap-2.5 py-3 border border-parchment-300 text-ink-400 font-body text-sm hover:bg-parchment-100 hover:text-clay-500 transition-colors group"
      >
        <LogOut className="w-4 h-4 flex-shrink-0 group-hover:text-clay-400 transition-colors" strokeWidth={1.5} />
        Sign Out
      </button>
    </div>
  );

  const deleteConfirmModal = deleteConfirmOpen && (
    <>
      <div className="fixed inset-0 bg-black/40 z-[60] transition-opacity" onClick={() => !deleting && setDeleteConfirmOpen(false)} />
      <div className="fixed inset-0 z-[70] flex items-center justify-center p-4">
        <div className="w-full max-w-sm bg-cream linen-texture border thin-rule rule-line container-radius p-8">
          <div className="flex flex-col items-center text-center mb-4">
            <AlertTriangle className="w-10 h-10 text-terracotta-600 mb-3" strokeWidth={1.5} />
            <h3 className="text-2xl font-display font-light text-slate-900">Delete account?</h3>
          </div>
          <p className="text-sm font-body text-slate-600 text-center mb-6">
            This permanently deletes your account and cannot be undone. Your profile, library, wishlist,
            game sessions, and friends will all be removed.
          </p>

          {deleteError && (
            <div className="px-4 py-3 mb-4 bg-terracotta-50 border thin-rule border-terracotta-300 text-terracotta-900 text-sm font-body input-radius">
              {deleteError}
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setDeleteConfirmOpen(false)}
              disabled={deleting}
              className="flex-1 py-2.5 border thin-rule rule-line font-body text-sm text-slate-700 hover:bg-slate-50 transition-colors disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleDeleteAccount}
              disabled={deleting}
              className="flex-1 py-2.5 bg-terracotta-700 text-cream font-body text-sm hover:bg-terracotta-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {deleting ? 'Deleting...' : 'Delete Account'}
            </button>
          </div>
        </div>
      </div>
    </>
  );

  if (mode === 'page') {
    return (
      <div className="min-h-screen bg-cream flex flex-col pb-24">
        <div className="flex items-center px-6 py-5 border-b thin-rule rule-line flex-shrink-0 sticky top-0 bg-cream z-10">
          <h2 className="text-2xl font-display font-light text-ink-600">Profile</h2>
        </div>
        <div className="flex-1 overflow-y-auto">
          {innerContent}
        </div>
        {footer}
        {deleteConfirmModal}
      </div>
    );
  }

  return (
    <>
      <div className="fixed inset-0 bg-black/40 z-40 transition-opacity" onClick={onClose} />
      <div className="fixed right-0 top-0 h-full w-full max-w-md bg-cream z-50 flex flex-col shadow-2xl">
        <div className="flex items-center justify-between px-6 py-5 border-b thin-rule rule-line flex-shrink-0">
          <h2 className="text-2xl font-display font-light text-slate-900">Profile</h2>
          <button onClick={onClose} className="p-2 hover:bg-slate-100 transition-colors" aria-label="Close">
            <X className="w-5 h-5 text-slate-500" strokeWidth={1.5} />
          </button>
        </div>
        {innerContent}
        {deleteConfirmModal}
        {footer}
      </div>
    </>
  );
}
