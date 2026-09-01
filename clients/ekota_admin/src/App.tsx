import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import LoginPage from './components/LoginPage';
import type { AuthSession } from './types/auth';

import { WithdrawalManagement } from './components/WithdrawalManagement';
import { PaymentAuditLog } from './components/PaymentAuditLog';
import { PostManagement } from './components/PostManagement';
import { UserManagement } from './components/UserManagement';

interface DashboardStats {
  users: {
    total: number;
    producers: number;
    investors: number;
    renters: number;
    blocked: number;
  };
  posts: {
    total: number;
    active: number;
    paused: number;
  };
  pendingActions: {
    withdrawals: number;
    payments: number;
    validatedPayments: number;
  };
  recentActivity: Array<{
    id: string;
    type: string;
    title: string;
    status: string;
    createdAt: string;
  }>;
  recentListings: Array<{
    id: string;
    producerName: string;
    assetName: string;
    category: string;
    rentalPrice: number;
    status: string;
    createdAt: string;
  }>;
}

function DashboardOverview({ onTabChange }: { onTabChange: (tab: 'overview' | 'posts' | 'users' | 'withdrawals' | 'payments') => void }) {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchStats = async () => {
    try {
      setLoading(true);
      const savedSession = sessionStorage.getItem('ekota_admin_session');
      const token = savedSession ? JSON.parse(savedSession).token : '';

      const res = await fetch('http://localhost:5000/api/admin/dashboard', {
        headers: {
          'Authorization': `Bearer ${token || 'dev-token'}`,
          'Content-Type': 'application/json',
        },
      });

      if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
      const data = await res.json();
      setStats(data);
      setError(null);
    } catch (err: any) {
      console.error('Error fetching admin dashboard stats:', err);
      setError(err.message || 'Failed to fetch live PostgreSQL dashboard metrics.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 10000);
    return () => clearInterval(interval);
  }, []);

  if (loading && !stats) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        <p style={{ fontSize: '16px', fontWeight: 600 }}>Loading marketplace operations metrics...</p>
      </div>
    );
  }

  if (error && !stats) {
    return (
      <div style={{ padding: '20px', background: '#fef2f2', border: '1px solid #fca5a5', borderRadius: '10px', color: '#b91c1c', margin: '20px' }}>
        <p style={{ margin: 0 }}><strong>Error loading dashboard metrics:</strong> {error}</p>
        <button onClick={fetchStats} style={{ marginTop: '12px', padding: '6px 14px', background: '#dc2626', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', fontWeight: 600 }}>Retry</button>
      </div>
    );
  }

  return (
    <div className="dashboard-scroll">
      {/* 1. Top Statistic Cards */}
      <div className="dashboard-grid">
        <div className="stat-card">
          <div className="stat-header">
            <h3 className="stat-title">Total Users</h3>
          </div>
          <p className="stat-value">{stats?.users.total.toLocaleString()}</p>
          <span className="stat-trend positive">● Live Registered Accounts</span>
        </div>

        <div className="stat-card">
          <div className="stat-header">
            <h3 className="stat-title">Producers</h3>
          </div>
          <p className="stat-value">{stats?.users.producers.toLocaleString()}</p>
          <span className="stat-trend neutral">Verified Asset Producers</span>
        </div>

        <div className="stat-card">
          <div className="stat-header">
            <h3 className="stat-title">Pending Actions</h3>
          </div>
          <p className="stat-value" style={{ color: '#b45309' }}>
            {(stats?.pendingActions.withdrawals || 0) + (stats?.pendingActions.payments || 0)}
          </p>
          <span className="stat-trend negative">Requires Admin Attention</span>
        </div>

        <div className="stat-card">
          <div className="stat-header">
            <h3 className="stat-title">Blocked Users</h3>
          </div>
          <p className="stat-value" style={{ color: '#b91c1c' }}>{stats?.users.blocked.toLocaleString()}</p>
          <span className="stat-trend negative">Frozen Accounts</span>
        </div>
      </div>

      {/* 2. User & Post Overviews */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.25rem', marginBottom: '1.5rem' }}>
        <div className="content-panel" style={{ margin: 0 }}>
          <h3>User Overview</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
              <span style={{ color: '#475569', fontWeight: 500, fontSize: '0.875rem' }}>Producers</span>
              <strong style={{ color: '#0f172a', fontSize: '0.875rem' }}>{stats?.users.producers}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
              <span style={{ color: '#475569', fontWeight: 500, fontSize: '0.875rem' }}>Investors</span>
              <strong style={{ color: '#0f172a', fontSize: '0.875rem' }}>{stats?.users.investors}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
              <span style={{ color: '#475569', fontWeight: 500, fontSize: '0.875rem' }}>Renters</span>
              <strong style={{ color: '#0f172a', fontSize: '0.875rem' }}>{stats?.users.renters}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#fef2f2', borderRadius: '8px', border: '1px solid #fca5a5' }}>
              <span style={{ color: '#991b1b', fontWeight: 500, fontSize: '0.875rem' }}>Blocked / Frozen</span>
              <strong style={{ color: '#b91c1c', fontSize: '0.875rem' }}>{stats?.users.blocked}</strong>
            </div>
          </div>
          <button onClick={() => onTabChange('users')} className="secondary" style={{ marginTop: '1.25rem', width: '100%', justifyContent: 'center' }}>
            Manage User Accounts →
          </button>
        </div>

        <div className="content-panel" style={{ margin: 0 }}>
          <h3>Post Overview</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
              <span style={{ color: '#475569', fontWeight: 500, fontSize: '0.875rem' }}>Total Producer Posts</span>
              <strong style={{ color: '#0f172a', fontSize: '0.875rem' }}>{stats?.posts.total}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#ecfdf5', borderRadius: '8px', border: '1px solid #a7f3d0' }}>
              <span style={{ color: '#047857', fontWeight: 500, fontSize: '0.875rem' }}>Active Listings</span>
              <strong style={{ color: '#047857', fontSize: '0.875rem' }}>{stats?.posts.active}</strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.75rem 1rem', background: '#fffbeb', borderRadius: '8px', border: '1px solid #fde68a' }}>
              <span style={{ color: '#b45309', fontWeight: 500, fontSize: '0.875rem' }}>Paused Listings</span>
              <strong style={{ color: '#b45309', fontSize: '0.875rem' }}>{stats?.posts.paused}</strong>
            </div>
          </div>
          <button onClick={() => onTabChange('posts')} className="secondary" style={{ marginTop: '1.25rem', width: '100%', justifyContent: 'center' }}>
            Manage Producer Posts →
          </button>
        </div>
      </div>

      {/* 3. Pending Actions */}
      <div className="content-panel">
        <h3>Pending Actions</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', background: '#fffbeb', border: '1px solid #fde68a', borderRadius: '10px' }}>
            <div>
              <strong style={{ display: 'block', color: '#b45309', fontSize: '0.95rem' }}>{stats?.pendingActions.withdrawals || 0} Payout Requests</strong>
              <span style={{ fontSize: '0.8125rem', color: '#b45309' }}>Producer withdrawals awaiting review</span>
            </div>
            <button onClick={() => onTabChange('withdrawals')} style={{ padding: '0.5rem 0.9rem', background: '#b45309', color: 'white', border: 'none', borderRadius: '6px', fontSize: '0.8125rem' }}>Review →</button>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '1rem', background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '10px' }}>
            <div>
              <strong style={{ display: 'block', color: '#1d4ed8', fontSize: '0.95rem' }}>{stats?.pendingActions.validatedPayments || 0} Validated Payments</strong>
              <span style={{ fontSize: '0.8125rem', color: '#1d4ed8' }}>SSLCommerz payments to audit</span>
            </div>
            <button onClick={() => onTabChange('payments')} style={{ padding: '0.5rem 0.9rem', background: '#1d4ed8', color: 'white', border: 'none', borderRadius: '6px', fontSize: '0.8125rem' }}>Audit →</button>
          </div>
        </div>
      </div>

      {/* 4. Live Recent Activity Timeline */}
      <div className="content-panel">
        <h3>Recent Activity Log</h3>
        {stats?.recentActivity && stats.recentActivity.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {stats.recentActivity.map(act => (
              <div key={act.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0.75rem 1rem', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                <div>
                  <p style={{ margin: 0, fontWeight: 600, color: '#0f172a', fontSize: '0.875rem' }}>{act.title}</p>
                  <span style={{ fontSize: '0.75rem', color: '#64748b' }}>{new Date(act.createdAt).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })}</span>
                </div>
                <span className={`status-badge status-${act.status.toLowerCase()}`}>
                  {act.status}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <p style={{ color: '#64748b', fontSize: '0.875rem', margin: 0 }}>No recent activity log found.</p>
        )}
      </div>

      {/* 5. Recent Asset Listings Verification Table */}
      <div className="content-panel" style={{ marginBottom: 0 }}>
        <h3>Recent Producer Asset Listings</h3>
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>Producer</th>
                <th>Asset Name</th>
                <th>Category</th>
                <th>Rental Price</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {stats?.recentListings && stats.recentListings.length > 0 ? (
                stats.recentListings.map(listing => (
                  <tr key={listing.id}>
                    <td style={{ fontWeight: 600 }}>{listing.producerName}</td>
                    <td>{listing.assetName}</td>
                    <td>{listing.category}</td>
                    <td style={{ fontWeight: 700, color: '#047857' }}>৳{listing.rentalPrice.toLocaleString('en-BD')} BDT</td>
                    <td>
                      <span className={`status-badge status-${listing.status === 'active' ? 'approved' : 'pending'}`}>
                        {listing.status}
                      </span>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} style={{ padding: '1.5rem', textAlign: 'center', color: '#64748b' }}>No asset listings found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function Dashboard({ onLogout }: { onLogout: () => void }) {
  const [currentTab, setCurrentTab] = useState<'overview' | 'posts' | 'users' | 'withdrawals' | 'payments'>('overview');

  return (
    <div className="admin-layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <h2>Ekota Admin</h2>
          <span className="badge-tag">PORTAL</span>
        </div>
        <nav className="sidebar-nav">
          <button
            type="button"
            className={`nav-item ${currentTab === 'overview' ? 'active' : ''}`}
            onClick={() => setCurrentTab('overview')}
          >
            Dashboard Overview
          </button>
          <button
            type="button"
            className={`nav-item ${currentTab === 'posts' ? 'active' : ''}`}
            onClick={() => setCurrentTab('posts')}
          >
            Producer Posts
          </button>
          <button
            type="button"
            className={`nav-item ${currentTab === 'users' ? 'active' : ''}`}
            onClick={() => setCurrentTab('users')}
          >
            User Accounts
          </button>
          <button
            type="button"
            className={`nav-item ${currentTab === 'withdrawals' ? 'active' : ''}`}
            onClick={() => setCurrentTab('withdrawals')}
          >
            Withdrawal Management
          </button>
          <button
            type="button"
            className={`nav-item ${currentTab === 'payments' ? 'active' : ''}`}
            onClick={() => setCurrentTab('payments')}
          >
            Payment Audit Log
          </button>
        </nav>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <h1 className="topbar-title">
            {currentTab === 'overview' && 'Dashboard Overview'}
            {currentTab === 'posts' && 'Producer Post Management'}
            {currentTab === 'users' && 'User Account Management'}
            {currentTab === 'withdrawals' && 'Withdrawal Request Management'}
            {currentTab === 'payments' && 'Payment Audit Log'}
          </h1>
          <div className="topbar-actions">
            <button type="button" className="secondary" style={{ fontSize: '0.8125rem' }}>Admin Settings</button>
            <button type="button" onClick={onLogout} style={{ fontSize: '0.8125rem' }}>Sign Out</button>
          </div>
        </header>

        {currentTab === 'overview' && <DashboardOverview onTabChange={setCurrentTab} />}
        {currentTab === 'posts' && <PostManagement />}
        {currentTab === 'users' && <UserManagement />}
        {currentTab === 'withdrawals' && <WithdrawalManagement />}
        {currentTab === 'payments' && <PaymentAuditLog />}
      </main>
    </div>
  );
}

function App() {
  const [session, setSession] = useState<AuthSession | null>(null);

  useEffect(() => {
    // Clear any legacy persistent localStorage session
    localStorage.removeItem('ekota_admin_session');

    const saved = sessionStorage.getItem('ekota_admin_session');
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        if (parsed && parsed.user && parsed.user.role === 'ADMIN') {
          setSession(parsed);
        } else {
          sessionStorage.removeItem('ekota_admin_session');
        }
      } catch {
        sessionStorage.removeItem('ekota_admin_session');
      }
    }
  }, []);

  const handleLogout = () => {
    sessionStorage.removeItem('ekota_admin_session');
    localStorage.removeItem('ekota_admin_session');
    setSession(null);
  };

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={!session ? <LoginPage onAuthenticated={setSession} /> : <Navigate to="/" />} />
        <Route path="/" element={session && session.user && session.user.role === 'ADMIN' ? <Dashboard onLogout={handleLogout} /> : <Navigate to="/login" />} />
        <Route path="*" element={<Navigate to="/login" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
