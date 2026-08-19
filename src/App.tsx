import React, { useState } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import AuthForm from './components/AuthForm';
import Library from './components/Library';
import AdminPanel from './components/AdminPanel';
import GameNiteTools from './components/GameNiteTools';
import Dashboard from './components/Dashboard';
import ProfileDrawer from './components/ProfileDrawer';
import { Shield, BookOpen, Sparkles, BarChart3 } from 'lucide-react';

type Tool = 'game-chooser' | 'first-player' | 'turn-timer' | 'game-timer';

const MeepleIcon = ({ className }: { className?: string }) => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className={className}>
    <circle cx="12" cy="5" r="3" />
    <path d="M6 9.5C4 9.5 3.5 11.5 5 13L6.5 16L4 22H9.5V17.5H14.5V22H20L17.5 16L19 13C20.5 11.5 20 9.5 18 9.5H6Z" />
  </svg>
);

const bottomNavColor = '#b85c28';

function AppContent() {
  const { user, profile, loading } = useAuth();
  const [activeTab, setActiveTab] = useState<'dashboard' | 'library' | 'gameNiteTools' | 'admin' | 'profile'>('dashboard');
  const [selectedTool, setSelectedTool] = useState<Tool | undefined>(undefined);
  const [isProfileDrawerOpen, setIsProfileDrawerOpen] = useState(false);

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-slate-900"></div>
      </div>
    );
  }

  if (!user) {
    return <AuthForm onSuccess={() => {}} />;
  }

  const isAdmin = profile?.is_admin || false;

  // ── Desktop nav tab accent colors ───────────────────────────────────────────
  const navColors: Record<string, string> = {
    dashboard: '#b85c28',
    library: '#3a7040',
    gameNiteTools: '#2e8282',
    admin: '#74389a',
  };

  // ── Bottom nav items ────────────────────────────────────────────────────────
  const bottomNavItems = [
    { tab: 'dashboard'     as const, icon: BarChart3, label: 'Dashboard'  },
    { tab: 'gameNiteTools' as const, icon: Sparkles,  label: 'Game Night' },
    { tab: 'library'       as const, icon: BookOpen,  label: 'My Games'   },
    ...(isAdmin ? [{ tab: 'admin' as const, icon: Shield, label: 'Admin' }] : []),
  ];

  return (
    <div className="min-h-screen bg-slate-50">

      {/* ── Desktop top nav (hidden on mobile) ───────────────────────────────── */}
      <div className="hidden md:block sticky top-0 z-50 border-b border-slate-200 bg-white overflow-visible">
        <div className="max-w-7xl mx-auto px-4">
          <nav className="flex items-center justify-between">
            <div className="flex items-center space-x-8">
              <div className="flex items-center space-x-2 py-4">
                <MeepleIcon className="w-8 h-8 text-slate-900" />
                <h1 className="text-2xl font-bold text-slate-900 font-display">
                  Churtern•Play
                </h1>
              </div>

              <div className="flex space-x-1">
                <button
                  onClick={() => setActiveTab('dashboard')}
                  className={`flex items-center space-x-2 px-6 py-4 font-medium transition rounded-md ${
                    activeTab === 'dashboard' ? '' : 'text-slate-600 hover:text-slate-900'
                  }`}
                  style={activeTab === 'dashboard' ? { color: navColors.dashboard, backgroundColor: `${navColors.dashboard}1a` } : undefined}
                >
                  <BarChart3 className="w-5 h-5" />
                  <span>Dashboard</span>
                </button>
                <button
                  onClick={() => setActiveTab('library')}
                  className={`flex items-center space-x-2 px-6 py-4 font-medium transition rounded-md ${
                    activeTab === 'library' ? '' : 'text-slate-600 hover:text-slate-900'
                  }`}
                  style={activeTab === 'library' ? { color: navColors.library, backgroundColor: `${navColors.library}1a` } : undefined}
                >
                  <BookOpen className="w-5 h-5" />
                  <span>My Catalogue</span>
                </button>
                <button
                  onClick={() => setActiveTab('gameNiteTools')}
                  className={`flex items-center space-x-2 px-6 py-4 font-medium transition rounded-md ${
                    activeTab === 'gameNiteTools' ? '' : 'text-slate-600 hover:text-slate-900'
                  }`}
                  style={activeTab === 'gameNiteTools' ? { color: navColors.gameNiteTools, backgroundColor: `${navColors.gameNiteTools}1a` } : undefined}
                >
                  <Sparkles className="w-5 h-5" />
                  <span>Game Nite Tools</span>
                </button>
                {isAdmin && (
                  <button
                    onClick={() => setActiveTab('admin')}
                    className={`flex items-center space-x-2 px-6 py-4 font-medium transition rounded-md ${
                      activeTab === 'admin' ? '' : 'text-slate-600 hover:text-slate-900'
                    }`}
                    style={activeTab === 'admin' ? { color: navColors.admin, backgroundColor: `${navColors.admin}1a` } : undefined}
                  >
                    <Shield className="w-5 h-5" />
                    <span>Admin</span>
                  </button>
                )}
              </div>
            </div>

            {profile && (
              <button
                onClick={() => setIsProfileDrawerOpen(true)}
                className="flex items-center space-x-2 px-6 py-4 font-medium transition text-slate-600 hover:text-slate-900"
              >
                <MeepleIcon className="w-5 h-5" />
                <span>{profile.username}</span>
              </button>
            )}
          </nav>
        </div>
      </div>

      {/* ── Mobile slim header (hidden on desktop) ───────────────────────────── */}
      <div className="md:hidden sticky top-0 z-50 bg-white border-b border-parchment-300">
        <div className="flex items-center justify-between px-4 py-3 gap-3">
          <div className="flex items-center gap-2">
            <MeepleIcon className="w-6 h-6 text-ink-600" />
            <h1 className="font-display font-light text-2xl text-ink-600 tracking-wide">Churtern•Play</h1>
          </div>
          {profile && (
            <button
              onClick={() => setIsProfileDrawerOpen(true)}
              className="w-8 h-8 rounded-full bg-clay-400 flex items-center justify-center flex-shrink-0"
            >
              <span className="text-cream font-body text-sm font-semibold">
                {profile.username.charAt(0).toUpperCase()}
              </span>
            </button>
          )}
        </div>
      </div>

      <ProfileDrawer isOpen={isProfileDrawerOpen} onClose={() => setIsProfileDrawerOpen(false)} />

      {/* ── Page content — bottom padding on mobile clears the fixed bottom nav ── */}
      <div className="pb-24 md:pb-0">
        {activeTab === 'dashboard' && (
          <Dashboard
            onNavigate={(tab, params) => {
              setActiveTab(tab);
              if (tab === 'gameNiteTools' && params?.tool) {
                setSelectedTool(params.tool);
              }
            }}
          />
        )}
        {activeTab === 'library' && <Library />}
        {activeTab === 'gameNiteTools' && <GameNiteTools initialTool={selectedTool} />}
        {activeTab === 'admin' && <AdminPanel />}
        {activeTab === 'profile' && (
          <div className="md:hidden">
            <ProfileDrawer mode="page" isOpen={true} onClose={() => setActiveTab('dashboard')} />
          </div>
        )}
      </div>

      {/* ── Mobile bottom nav (hidden on desktop) ────────────────────────────── */}
      <nav
        className="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-white border-t border-slate-200"
        style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
      >
        <div className="flex">
          {bottomNavItems.map(({ tab, icon: Icon, label }) => {
            const isActive = activeTab === tab;
            return (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`flex-1 flex flex-col items-center justify-center pt-2 pb-1.5 gap-0.5 transition-colors ${
                  isActive ? '' : 'text-slate-400'
                }`}
                style={isActive ? { color: bottomNavColor, backgroundColor: `${bottomNavColor}1a` } : undefined}
              >
                <Icon className="w-5 h-5" />
                <span className={`text-xs font-body ${isActive ? 'font-medium' : ''}`}>
                  {label}
                </span>
              </button>
            );
          })}

          {/* Profile — full page tab on mobile */}
          <button
            onClick={() => setActiveTab('profile')}
            className={`flex-1 flex flex-col items-center justify-center pt-2 pb-1.5 gap-0.5 transition-colors ${
              activeTab === 'profile' ? '' : 'text-slate-400'
            }`}
            style={activeTab === 'profile' ? { color: bottomNavColor, backgroundColor: `${bottomNavColor}1a` } : undefined}
          >
            <MeepleIcon className="w-5 h-5" />
            <span className={`text-xs font-body ${activeTab === 'profile' ? 'font-medium' : ''}`}>Profile</span>
          </button>
        </div>
      </nav>
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
