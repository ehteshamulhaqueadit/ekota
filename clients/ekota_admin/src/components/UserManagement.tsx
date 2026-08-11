import React, { useState, useEffect } from 'react';
import { apiRequest } from '../lib/api';

interface UserAccount {
  id: string;
  fullName: string;
  email: string;
  phoneNumber?: string;
  role: 'PRODUCER' | 'INVESTOR' | 'RENTER' | 'ADMIN';
  isBlocked: boolean;
  blockedReason?: string | null;
  kycStatus: string;
  createdAt: string;
}

export const UserManagement: React.FC = () => {
  const [users, setUsers] = useState<UserAccount[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [search, setSearch] = useState<string>('');
  const [roleFilter, setRoleFilter] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('');

  // Block Modal state
  const [blockingUser, setBlockingUser] = useState<UserAccount | null>(null);
  const [blockReason, setBlockReason] = useState<string>('');
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState<boolean>(false);

  useEffect(() => {
    fetchUsers();
  }, [roleFilter, statusFilter]);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      let query = '/admin/users?';
      if (roleFilter) query += `role=${roleFilter}&`;
      if (statusFilter) query += `isBlocked=${statusFilter === 'blocked' ? 'true' : 'false'}&`;
      if (search) query += `search=${encodeURIComponent(search)}&`;

      const data = await apiRequest(query) as UserAccount[];
      setUsers(Array.isArray(data) ? data : []);
    } catch (_err) {
      // Fallback mock users
      setUsers([
        {
          id: '10000000-0000-0000-0000-000000000001',
          email: 'producer_karim@ekota.com',
          fullName: 'Karim Agro',
          phoneNumber: '+8801700000001',
          role: 'PRODUCER',
          isBlocked: false,
          blockedReason: null,
          kycStatus: 'VERIFIED',
          createdAt: new Date().toISOString()
        },
        {
          id: '10000000-0000-0000-0000-000000000002',
          email: 'investor_tariq@ekota.com',
          fullName: 'Tariq Rahman',
          phoneNumber: '+8801800000002',
          role: 'INVESTOR',
          isBlocked: false,
          blockedReason: null,
          kycStatus: 'VERIFIED',
          createdAt: new Date().toISOString()
        },
        {
          id: '10000000-0000-0000-0000-000000000003',
          email: 'renter_rahim@ekota.com',
          fullName: 'Rahim Transport',
          phoneNumber: '+8801900000003',
          role: 'RENTER',
          isBlocked: true,
          blockedReason: 'Pending identity verification investigation',
          kycStatus: 'PENDING',
          createdAt: new Date().toISOString()
        }
      ]);
    } finally {
      setLoading(false);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchUsers();
  };

  const openBlockModal = (user: UserAccount) => {
    setBlockingUser(user);
    setBlockReason('');
    setActionError(null);
  };

  const handleConfirmBlock = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!blockingUser || !blockReason.trim()) return;
    setSubmitting(true);
    setActionError(null);

    try {
      const res = await apiRequest(`/admin/users/${blockingUser.id}/block`, {
        method: 'POST',
        body: JSON.stringify({ reason: blockReason.trim() })
      }) as { message?: string };

      setActionSuccess(res.message || `Account for ${blockingUser.fullName} has been blocked and frozen.`);
      setBlockingUser(null);
      fetchUsers();
    } catch (err: any) {
      setActionError(err.message || 'Failed to block user account');
    } finally {
      setSubmitting(false);
    }
  };

  const handleUnblockUser = async (user: UserAccount) => {
    if (!window.confirm(`Are you sure you want to unblock ${user.fullName} (${user.email})?`)) return;
    setSubmitting(true);
    setActionError(null);

    try {
      const res = await apiRequest(`/admin/users/${user.id}/unblock`, {
        method: 'POST'
      }) as { message?: string };

      setActionSuccess(res.message || `Account for ${user.fullName} has been unblocked.`);
      fetchUsers();
    } catch (err: any) {
      setActionError(err.message || 'Failed to unblock user account');
    } finally {
      setSubmitting(false);
    }
  };

  const filteredUsers = users.filter(u => {
    if (!search) return true;
    const term = search.toLowerCase();
    return (
      u.fullName.toLowerCase().includes(term) ||
      u.email.toLowerCase().includes(term) ||
      (u.phoneNumber && u.phoneNumber.toLowerCase().includes(term))
    );
  });

  return (
    <div className="dashboard-scroll">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '1.5rem', fontWeight: 600 }}>User Account Management</h2>
          <p style={{ color: 'var(--text-secondary)', margin: '0.25rem 0 0 0', fontSize: '0.875rem' }}>
            Manage producer, investor, and renter accounts. Block/freeze accounts with email alerts until innocence is proven.
          </p>
        </div>
      </div>

      {actionSuccess && (
        <div style={{ background: 'rgba(16, 185, 129, 0.15)', border: '1px solid var(--success-color)', color: '#34d399', padding: '0.75rem 1rem', borderRadius: '8px', marginBottom: '1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>{actionSuccess}</span>
          <button type="button" onClick={() => setActionSuccess(null)} style={{ background: 'none', border: 'none', color: '#34d399', cursor: 'pointer', fontSize: '1.1rem' }}>✕</button>
        </div>
      )}

      {/* Filter Bar */}
      <div className="content-panel" style={{ marginBottom: '1.5rem', padding: '1rem' }}>
        <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '1rem', alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: '240px' }}>
            <input
              type="text"
              placeholder="Search user by name, email, or phone number..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                width: '100%',
                padding: '0.6rem 1rem',
                borderRadius: '8px',
                border: '1px solid var(--border-color)',
                background: 'var(--bg-color)',
                color: 'var(--text-primary)'
              }}
            />
          </div>
          <div>
            <select
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
              style={{
                padding: '0.6rem 1rem',
                borderRadius: '8px',
                border: '1px solid var(--border-color)',
                background: 'var(--bg-color)',
                color: 'var(--text-primary)'
              }}
            >
              <option value="">All Roles</option>
              <option value="PRODUCER">Producers</option>
              <option value="INVESTOR">Investors</option>
              <option value="RENTER">Renters</option>
            </select>
          </div>
          <div>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              style={{
                padding: '0.6rem 1rem',
                borderRadius: '8px',
                border: '1px solid var(--border-color)',
                background: 'var(--bg-color)',
                color: 'var(--text-primary)'
              }}
            >
              <option value="">All Account Statuses</option>
              <option value="active">Active Accounts</option>
              <option value="blocked">Blocked / Frozen Accounts</option>
            </select>
          </div>
          <button type="submit" style={{ padding: '0.6rem 1.2rem' }}>Search</button>
        </form>
      </div>

      {/* Users Table */}
      <div className="content-panel">
        <div className="table-container">
          {loading ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-secondary)' }}>Loading user accounts...</div>
          ) : filteredUsers.length === 0 ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-secondary)' }}>No user accounts found matching criteria.</div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>User Details</th>
                  <th>Role</th>
                  <th>KYC Status</th>
                  <th>Account Status</th>
                  <th>Blocked Reason</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{user.fullName}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>{user.email}</div>
                      {user.phoneNumber && <div style={{ fontSize: '0.7rem', color: 'var(--text-secondary)' }}>{user.phoneNumber}</div>}
                    </td>
                    <td>
                      <span style={{
                        fontSize: '0.8rem',
                        fontWeight: 600,
                        padding: '0.2rem 0.6rem',
                        borderRadius: '4px',
                        background: user.role === 'PRODUCER' ? 'rgba(99, 102, 241, 0.15)' :
                          user.role === 'INVESTOR' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(245, 158, 11, 0.15)',
                        color: user.role === 'PRODUCER' ? '#818cf8' :
                          user.role === 'INVESTOR' ? '#34d399' : '#fbbf24'
                      }}>
                        {user.role}
                      </span>
                    </td>
                    <td>
                      <span className={`status-badge ${user.kycStatus === 'VERIFIED' ? 'status-approved' : 'status-pending'}`}>
                        {user.kycStatus}
                      </span>
                    </td>
                    <td>
                      {user.isBlocked ? (
                        <span className="status-badge status-rejected" style={{ background: 'rgba(239, 68, 68, 0.2)', color: '#f87171' }}>
                          FROZEN / BLOCKED
                        </span>
                      ) : (
                        <span className="status-badge status-approved">
                          ACTIVE
                        </span>
                      )}
                    </td>
                    <td style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', maxWidth: '240px' }}>
                      {user.isBlocked ? (user.blockedReason || 'Reason not specified') : '-'}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      {user.role !== 'ADMIN' && (
                        user.isBlocked ? (
                          <button
                            type="button"
                            onClick={() => handleUnblockUser(user)}
                            style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem', background: 'var(--success-color)', color: '#fff' }}
                          >
                            Unblock Account
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={() => openBlockModal(user)}
                            style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem', background: 'var(--danger-color)', color: '#fff' }}
                          >
                            Block Account
                          </button>
                        )
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Block Account Modal */}
      {blockingUser && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0, 0, 0, 0.75)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100
        }}>
          <div style={{
            background: 'var(--surface-color)', padding: '2rem', borderRadius: '12px',
            maxWidth: '520px', width: '90%', border: '1px solid var(--border-color)'
          }}>
            <h3 style={{ marginTop: 0, marginBottom: '0.5rem', color: 'var(--danger-color)' }}>
              Temporarily Block Account
            </h3>
            <p style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', marginBottom: '1.25rem' }}>
              You are about to freeze the account for <strong>{blockingUser.fullName} ({blockingUser.email})</strong>. The user will receive an automated email detailing the freeze and instructions on proving innocence.
            </p>

            {actionError && (
              <div style={{ background: 'rgba(239, 68, 68, 0.15)', border: '1px solid var(--danger-color)', color: '#f87171', padding: '0.5rem 1rem', borderRadius: '6px', marginBottom: '1rem' }}>
                {actionError}
              </div>
            )}

            <form onSubmit={handleConfirmBlock}>
              <div style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>
                  Reason for Blocking / Freezing <span style={{ color: 'var(--danger-color)' }}>*</span>
                </label>
                <textarea
                  rows={4}
                  required
                  placeholder="Provide a clear explanation for why this account is being blocked (e.g. fraudulent activity, reported misconduct, policy violation)..."
                  value={blockReason}
                  onChange={(e) => setBlockReason(e.target.value)}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
                <button type="button" className="secondary" onClick={() => setBlockingUser(null)}>Cancel</button>
                <button type="submit" disabled={submitting} style={{ background: 'var(--danger-color)', color: '#fff' }}>
                  {submitting ? 'Freezing Account...' : 'Block & Freeze Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
