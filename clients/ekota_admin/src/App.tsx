import React, { useState } from 'react';
import { WithdrawalManagement } from './components/WithdrawalManagement';
import { PaymentAuditLog } from './components/PaymentAuditLog';

function App() {
  const [activeMenu, setActiveMenu] = useState<'withdrawals' | 'payments' | 'dashboard'>('withdrawals');

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#f8fafc', fontFamily: 'Inter, system-ui, sans-serif' }}>
      {/* Figma Dark Green Sidebar */}
      <aside style={{
        width: '240px',
        background: '#052E21',
        color: '#ffffff',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        padding: '24px 16px',
        flexShrink: 0,
      }}>
        <div>
          {/* Logo */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '0 8px 30px' }}>
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '8px',
              background: '#059669',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 800,
              color: '#ffffff',
            }}>
              E
            </div>
            <div>
              <div style={{ fontWeight: 800, fontSize: '18px', letterSpacing: '-0.02em' }}>Ekota</div>
              <div style={{ fontSize: '10px', color: '#6ee7b7' }}>Admin Panel</div>
            </div>
          </div>

          {/* Navigation Items */}
          <nav style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            {[
              { id: 'dashboard', label: 'Dashboard', icon: '📊' },
              { id: 'projects', label: 'Projects', icon: '📁' },
              { id: 'producers', label: 'Producers', icon: '🧑‍🌾' },
              { id: 'withdrawals', label: 'Withdrawals', icon: '💸' },
              { id: 'payments', label: 'SSLCommerz Payments', icon: '💳' },
              { id: 'users', label: 'Users', icon: '👥' },
              { id: 'reports', label: 'Reports', icon: '📈' },
              { id: 'notifications', label: 'Notifications', icon: '🔔' },
              { id: 'settings', label: 'Settings', icon: '⚙️' },
            ].map(item => {
              const isActive = activeMenu === item.id || (item.id === 'withdrawals' && activeMenu === 'withdrawals');
              return (
                <button
                  key={item.id}
                  onClick={() => {
                    if (item.id === 'withdrawals' || item.id === 'payments' || item.id === 'dashboard') {
                      setActiveMenu(item.id as any);
                    }
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '12px',
                    padding: '10px 12px',
                    borderRadius: '8px',
                    border: 'none',
                    background: isActive ? 'rgba(255, 255, 255, 0.12)' : 'transparent',
                    color: isActive ? '#ffffff' : '#a7f3d0',
                    fontWeight: isActive ? 700 : 500,
                    fontSize: '13px',
                    cursor: 'pointer',
                    textAlign: 'left',
                    width: '100%',
                  }}
                >
                  <span>{item.icon}</span>
                  <span>{item.label}</span>
                </button>
              );
            })}
          </nav>
        </div>

        {/* Footer User */}
        <div style={{ paddingTop: '20px', borderTop: '1px solid rgba(255, 255, 255, 0.1)', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div style={{
            width: '32px',
            height: '32px',
            borderRadius: '50%',
            background: '#10b981',
            color: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontWeight: 700,
            fontSize: '12px',
          }}>
            SA
          </div>
          <div>
            <div style={{ fontSize: '13px', fontWeight: 600 }}>Super Admin</div>
            <div style={{ fontSize: '10px', color: '#6ee7b7' }}>admin@ekota.com.bd</div>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <main style={{ flex: 1, padding: '24px 32px', overflowY: 'auto' }}>
        {/* Role Switcher bar */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          background: '#052E21',
          padding: '8px 16px',
          borderRadius: '8px',
          color: '#ffffff',
          marginBottom: '20px',
          fontSize: '12px',
        }}>
          <div style={{ display: 'flex', gap: '16px' }}>
            <span style={{ color: '#a7f3d0', cursor: 'pointer' }}>Renter/Investor</span>
            <span style={{ color: '#a7f3d0', cursor: 'pointer' }}>Producer</span>
            <span style={{ fontWeight: 700, borderBottom: '2px solid #34d399', paddingBottom: '2px' }}>Admin</span>
          </div>
          <div style={{ color: '#6ee7b7' }}>System Active</div>
        </div>

        {activeMenu === 'withdrawals' && <WithdrawalManagement />}
        {activeMenu === 'payments' && <PaymentAuditLog />}
        {activeMenu === 'dashboard' && <WithdrawalManagement />}
      </main>
    </div>
  );
}

export default App;
