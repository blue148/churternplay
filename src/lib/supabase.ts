import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export interface Game {
  id: string;
  barcode: string;
  name: string;
  bgg_id?: number;
  publisher?: string;
  year?: string;
  edition?: string;
  cover_image?: string;
  game_type?: string[];
  game_category?: string[];
  game_mechanic?: string[];
  game_family?: string[];
  min_players?: number;
  max_players?: number;
  playtime_minutes?: number;
  is_expansion?: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserLibraryEntry {
  id: string;
  user_id: string;
  game_id: string;
  is_favorite: boolean;
  for_sale: boolean;
  personal_ranking?: 'high' | 'medium' | 'low';
  played_dates?: string[];
  notes?: string;
  added_date: string;
  updated_at: string;
  game?: Game;
}

export interface UserWishlistEntry {
  id: string;
  user_id: string;
  game_id: string;
  priority: 'high' | 'medium' | 'low';
  notes?: string;
  added_date: string;
  updated_at: string;
  game?: Game;
}

export interface GameSession {
  id: string;
  user_id: string;
  game_id: string;
  session_date: string;
  duration_minutes?: number;
  player_count?: number;
  notes?: string;
  created_at: string;
  updated_at: string;
  victories?: SessionVictory[];
  game?: Game;
}

export interface SessionVictory {
  id: string;
  session_id: string;
  player_name: string;
  is_winner: boolean;
  score?: number;
  placement?: number;
  created_at: string;
}

export interface VictoryStats {
  total_sessions: number;
  total_wins: number;
  win_rate: number;
  best_score?: number;
  last_played?: string;
}

export interface UserLibraryEntryWithStats extends UserLibraryEntry {
  victory_stats?: VictoryStats;
}

export interface Profile {
  id: string;
  email: string;
  username: string;
  avatar_url?: string;
  bio?: string;
  phone?: string;
  preferences: {
    theme: 'light' | 'dark';
    notifications_enabled: boolean;
    default_view: 'grid' | 'list';
    players?: string[];
    game_timer?: {
      started_at: string | null;
      stopped_at: string | null;
      is_running: boolean;
    };
  };
  total_games: number;
  favorite_count: number;
  is_admin: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserFriend {
  id: string;
  user_id: string;
  friend_id: string;
  status: 'pending' | 'accepted' | 'blocked';
  created_at: string;
  updated_at: string;
  friend?: Profile;
}

export interface SharedLibraryAccess {
  id: string;
  owner_id: string;
  viewer_id: string;
  access_level: 'view' | 'suggest';
  granted_at: string;
  created_at: string;
  updated_at: string;
  owner?: Profile;
  viewer?: Profile;
}

export interface SharedLibrary {
  owner: Profile;
  game_count: number;
  last_updated: string;
  access_level: 'view' | 'suggest';
}

export interface SharedGameEntry {
  game: Game;
  owner: Profile;
  source: 'own' | 'shared';
}
