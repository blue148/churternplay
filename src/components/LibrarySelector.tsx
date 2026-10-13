import { useState, useEffect } from 'react';
import { ChevronDown, Users, Clock, Search, X } from 'lucide-react';
import { SharedLibrary } from '../lib/supabase';
import { getSharedLibraries } from '../lib/games';
import { useAuth } from '../contexts/AuthContext';

interface LibrarySelectorProps {
  selectedLibrary: SharedLibrary | null;
  onSelectLibrary: (library: SharedLibrary | null) => void;
  onClose?: () => void;
}

export default function LibrarySelector({
  selectedLibrary,
  onSelectLibrary,
  onClose
}: LibrarySelectorProps) {
  const { user } = useAuth();
  const [sharedLibraries, setSharedLibraries] = useState<SharedLibrary[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    loadSharedLibraries();
  }, [user]);

  const loadSharedLibraries = async () => {
    if (!user) return;

    try {
      setLoading(true);
      const libraries = await getSharedLibraries(user.id);
      setSharedLibraries(libraries);
    } catch (error) {
      console.error('Error loading shared libraries:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredLibraries = sharedLibraries.filter(library =>
    library.owner.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (library.owner.full_name ?? '').toLowerCase().includes(searchQuery.toLowerCase())
  );

  const formatLastUpdated = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));

    if (diffInDays === 0) return 'Today';
    if (diffInDays === 1) return 'Yesterday';
    if (diffInDays < 7) return `${diffInDays} days ago`;
    if (diffInDays < 30) return `${Math.floor(diffInDays / 7)} weeks ago`;
    return date.toLocaleDateString();
  };

  const handleSelectLibrary = (library: SharedLibrary) => {
    onSelectLibrary(library);
    setIsOpen(false);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-slate-900"></div>
      </div>
    );
  }

  // Mobile modal view
  if (isOpen) {
    return (
      <div className="fixed inset-0 bg-black/50 flex flex-col z-50">
        {/* Header */}
        <div className="bg-white px-4 py-4 border-b border-slate-200 flex items-center justify-between">
          <h2 className="text-lg font-display font-light text-slate-900">Choose Library</h2>
          <button
            onClick={() => {
              setIsOpen(false);
              onClose?.();
            }}
            className="p-2 text-slate-600 hover:text-slate-900 transition"
          >
            <X className="w-5 h-5" strokeWidth={1.5} />
          </button>
        </div>

        {/* Search */}
        <div className="bg-white px-4 py-3 border-b border-slate-200">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-slate-400" strokeWidth={1.5} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search friends..."
              className="w-full pl-10 pr-4 py-2 text-sm font-body bg-slate-50 border border-slate-200 rounded-lg focus:outline-none focus:bg-white focus:border-slate-400 transition-colors"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-slate-400 hover:text-slate-600 transition"
              >
                <X className="w-4 h-4" strokeWidth={1.5} />
              </button>
            )}
          </div>
        </div>

        {/* Library List */}
        <div className="flex-1 overflow-y-auto bg-white">
          {filteredLibraries.length === 0 ? (
            <div className="text-center py-12">
              <Users className="w-12 h-12 text-slate-300 mx-auto mb-4" strokeWidth={1.5} />
              <p className="text-slate-600 font-body">
                {searchQuery ? 'No libraries found' : 'No shared libraries yet'}
              </p>
              <p className="text-sm text-slate-500 mt-2">
                {searchQuery ? 'Try a different search' : 'Ask friends to share their libraries with you'}
              </p>
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {filteredLibraries.map((library) => (
                <button
                  key={library.owner.id}
                  onClick={() => handleSelectLibrary(library)}
                  className={`w-full px-4 py-4 text-left hover:bg-slate-50 transition ${
                    selectedLibrary?.owner.id === library.owner.id ? 'bg-purple-50 border-r-2 border-purple-500' : ''
                  }`}
                >
                  <div className="flex items-center space-x-3">
                    {library.owner.avatar_url ? (
                      <img
                        src={library.owner.avatar_url}
                        alt={library.owner.username}
                        className="w-10 h-10 rounded-full object-cover"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-400 to-pink-400 flex items-center justify-center">
                        <span className="text-white font-medium text-sm">
                          {library.owner.username.charAt(0).toUpperCase()}
                        </span>
                      </div>
                    )}

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <h3 className="font-body font-medium text-slate-900 truncate">
                          {library.owner.username}
                        </h3>
                        <div className="flex items-center space-x-1 text-slate-500 text-sm">
                          <Users className="w-3.5 h-3.5" strokeWidth={1.5} />
                          <span>{library.game_count}</span>
                        </div>
                      </div>
                      <div className="flex items-center space-x-4 mt-1">
                        <p className="text-sm text-slate-600 truncate">
                          {library.game_count} {library.game_count === 1 ? 'game' : 'games'}
                        </p>
                        <div className="flex items-center space-x-1 text-xs text-slate-500">
                          <Clock className="w-3 h-3" strokeWidth={1.5} />
                          <span>{formatLastUpdated(library.last_updated)}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  // Compact selector button
  return (
    <div className="space-y-3">
      {selectedLibrary && (
        <div className="bg-purple-50 border border-purple-200 rounded-lg p-3">
          <div className="flex items-center space-x-3">
            {selectedLibrary.owner.avatar_url ? (
              <img
                src={selectedLibrary.owner.avatar_url}
                alt={selectedLibrary.owner.username}
                className="w-8 h-8 rounded-full object-cover"
              />
            ) : (
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-400 to-pink-400 flex items-center justify-center">
                <span className="text-white font-medium text-xs">
                  {selectedLibrary.owner.username.charAt(0).toUpperCase()}
                </span>
              </div>
            )}
            <div className="flex-1 min-w-0">
              <p className="font-body font-medium text-slate-900 text-sm truncate">
                {selectedLibrary.owner.username}'s Library
              </p>
              <p className="text-xs text-slate-600">
                {selectedLibrary.game_count} games
              </p>
            </div>
            <button
              onClick={() => onSelectLibrary(null)}
              className="p-1 text-slate-400 hover:text-slate-600 transition"
            >
              <X className="w-4 h-4" strokeWidth={1.5} />
            </button>
          </div>
        </div>
      )}

      <button
        onClick={() => setIsOpen(true)}
        className="w-full flex items-center justify-between p-3 bg-white border border-slate-300 rounded-lg hover:bg-slate-50 transition text-left"
      >
        <div className="flex items-center space-x-3">
          <Users className="w-5 h-5 text-slate-600" strokeWidth={1.5} />
          <div>
            <p className="font-body font-medium text-slate-900 text-sm">
              {selectedLibrary ? 'Change Library' : 'Choose Friend Library'}
            </p>
            <p className="text-xs text-slate-600">
              {sharedLibraries.length} {sharedLibraries.length === 1 ? 'library' : 'libraries'} available
            </p>
          </div>
        </div>
        <ChevronDown className="w-5 h-5 text-slate-400" strokeWidth={1.5} />
      </button>
    </div>
  );
}