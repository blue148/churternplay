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

/**
 * Looks up the email tied to a phone number. The resolve_phone_login RPC only
 * returns it when the password also matches (and throttles failures), so it
 * can't be used to map phone numbers to email addresses.
 */
async function getEmailByPhone(phone: string, password: string) {
  const { data, error } = await supabase.rpc('resolve_phone_login', {
    p_phone: phone,
    p_password: password,
  });

  if (error) throw error;
  if (!data) throw new Error('Invalid login credentials');
  return data as string;
}

/** Signs in with an email or a phone number, resolving phone to its account's email first. */
export async function signIn(identifier: string, password: string) {
  const email = isEmail(identifier) ? identifier : await getEmailByPhone(identifier, password);

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) throw error;
  return data;
}

/**
 * Sends a password-reset email. Email only: resolving a phone number to an
 * email without the password would let anyone look up whose number is whose.
 * Supabase doesn't reveal whether the email is registered.
 */
export async function requestPasswordReset(email: string) {
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
