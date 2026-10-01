import { supabase } from './supabase';

export async function signUp(email: string, password: string, username: string, phone?: string) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        username,
        ...(phone ? { phone } : {}),
      },
    },
  });

  if (error) throw error;
  return data;
}

function isEmail(identifier: string) {
  return identifier.includes('@');
}

/** Looks up the email tied to a phone number, matching by digits only. */
async function getEmailByPhone(phone: string) {
  const digits = phone.replace(/\D/g, '');
  const { data, error } = await supabase
    .from('profiles')
    .select('email')
    .eq('phone_digits', digits)
    .maybeSingle();

  if (error) throw error;
  if (!data) throw new Error('Invalid login credentials');
  return data.email as string;
}

/** Resolves an email-or-phone identifier to the account's email. */
export async function resolveLoginEmail(identifier: string) {
  return isEmail(identifier) ? identifier : await getEmailByPhone(identifier);
}

/** Signs in with an email or a phone number, resolving phone to its account's email first. */
export async function signIn(identifier: string, password: string) {
  const email = await resolveLoginEmail(identifier);

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) throw error;
  return data;
}

/**
 * Sends a password-reset email, resolving phone to its account's email first.
 * Silently no-ops for an unrecognized phone number (rather than the caller's
 * generic "not found" error) so this can't be used to enumerate registered
 * phone numbers — callers should show the same "check your email" message
 * whether or not anything was actually sent, same as Supabase already does
 * for unrecognized emails.
 */
export async function requestPasswordReset(identifier: string) {
  let email: string;
  try {
    email = await resolveLoginEmail(identifier);
  } catch {
    return;
  }

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin,
  });

  if (error) throw error;
}

export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

export async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function getProfile(userId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) throw error;
  return data;
}

export async function updateProfile(userId: string, updates: {
  username?: string;
  avatar_url?: string;
  bio?: string;
  phone?: string | null;
  preferences?: Record<string, unknown>;
}) {
  const { data, error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('id', userId)
    .select()
    .single();

  if (error) throw error;
  return data;
}
