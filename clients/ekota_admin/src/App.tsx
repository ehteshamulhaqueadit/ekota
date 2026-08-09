import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import LoginPage from './components/LoginPage';
import type { AuthSession } from './types/auth';



function Dashboard({ onLogout }: { onLogout: () => void }) {
  return (
    <div className="admin-layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <h2>Ekota Admin</h2>
        </div>
        <nav className="sidebar-nav">
          <a href="#" className="nav-item active">Dashboard</a>
          <a href="#" className="nav-item">Verification Queue</a>
          <a href="#" className="nav-item">Users & Roles</a>
          <a href="#" className="nav-item">System Settings</a>
        </nav>
      </aside>

      <main className="main-content">
        <header className="topbar">
          <h1 className="topbar-title">Dashboard Overview</h1>
          <div className="topbar-actions">
            <button type="button" className="secondary">Settings</button>
            <button type="button" onClick={onLogout}>Sign Out</button>
          </div>
        </header>

        <div className="dashboard-scroll">
          <div className="dashboard-grid">
            <div className="stat-card">
              <div className="stat-header">
                <h3 className="stat-title">Active Districts</h3>
              </div>
              <p className="stat-value">128</p>
              <span className="stat-trend positive">+4 from last week</span>
            </div>
            <div className="stat-card">
              <div className="stat-header">
                <h3 className="stat-title">Pending Reviews</h3>
              </div>
              <p className="stat-value">24</p>
              <span className="stat-trend negative">Requires attention</span>
            </div>
            <div className="stat-card">
              <div className="stat-header">
                <h3 className="stat-title">Synced Today</h3>
              </div>
              <p className="stat-value">9.4k</p>
              <span className="stat-trend positive">+12% vs yesterday</span>
            </div>
          </div>

          <div className="content-panel">
            <h3>Recent Verification Requests</h3>
            <div className="table-container">
              <table>
                <thead>
                  <tr>
                    <th>Producer</th>
                    <th>Item Type</th>
                    <th>Date Submitted</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Amina Rahman</td>
                    <td>Organic Rice (100kg)</td>
                    <td>2 hours ago</td>
                    <td><span className="status-badge status-pending">Pending</span></td>
                  </tr>
                  <tr>
                    <td>Karim Agro</td>
                    <td>Fresh Tomatoes</td>
                    <td>5 hours ago</td>
                    <td><span className="status-badge status-approved">Approved</span></td>
                  </tr>
                  <tr>
                    <td>Rahim Traders</td>
                    <td>Jute (500kg)</td>
                    <td>Yesterday</td>
                    <td><span className="status-badge status-approved">Approved</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

function App() {
  const [session, setSession] = useState<AuthSession | null>(null);

  useEffect(() => {
    const saved = localStorage.getItem('ekota_admin_session');
    if (saved) {
      try {
        setSession(JSON.parse(saved));
      } catch {
        localStorage.removeItem('ekota_admin_session');
      }
    }
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('ekota_admin_session');
    setSession(null);
  };

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={!session ? <LoginPage onAuthenticated={setSession} /> : <Navigate to="/" />} />
        <Route path="/signup" element={!session ? <LoginPage onAuthenticated={setSession} /> : <Navigate to="/" />} />
        <Route path="/verify" element={!session ? <LoginPage onAuthenticated={setSession} /> : <Navigate to="/" />} />
        <Route path="/forgot-password" element={!session ? <LoginPage onAuthenticated={setSession} /> : <Navigate to="/" />} />
        <Route path="/reset-password" element={!session ? <LoginPage onAuthenticated={setSession} /> : <Navigate to="/" />} />
        <Route path="/" element={session ? <Dashboard onLogout={handleLogout} /> : <Navigate to="/login" />} />
        <Route path="*" element={<Navigate to="/" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
