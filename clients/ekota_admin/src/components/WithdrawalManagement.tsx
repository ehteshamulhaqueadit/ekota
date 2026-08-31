import React, { useState, useEffect } from 'react';
import { apiRequest } from '../lib/api';

interface ProducerInfo {
  id: string;
  fullName: string;
  email: string;
  phoneNumber?: string;
  kycStatus: string;
  avatarInitials: string;
}

interface WithdrawalRequest {
  id: string;
  producerId: string;
  producer: ProducerInfo;
  amount: number;
  method: string;
  accountNumber: string;
  accountDetails?: { accountNumber?: string };
  walletBalance: number;
  requestDate: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'Pending' | 'Approved' | 'Rejected';
  adminNote?: string;
  processedAt?: string;
  transactionRef?: string;
}

export const WithdrawalManagement: React.FC = () => {
  const [requests, setRequests] = useState<WithdrawalRequest[]>([]);
  const [filter, setFilter] = useState<string>('ALL');
  const [loading, setLoading] = useState<boolean>(true);
  const [selectedRequest, setSelectedRequest] = useState<WithdrawalRequest | null>(null);
  const [actionStatus, setActionStatus] = useState<'APPROVED' | 'REJECTED'>('APPROVED');
  const [adminNote, setAdminNote] = useState<string>('');
  const [notifyProducer, setNotifyProducer] = useState<boolean>(true);

  useEffect(() => {
    fetchWithdrawals();
  }, [filter]);

  const fetchWithdrawals = async () => {
    setLoading(true);
    try {
      const data = await apiRequest(`/withdrawals?status=${filter}`) as { success?: boolean; requests?: WithdrawalRequest[] };
      if (data && data.requests) {
        setRequests(data.requests);
      }
    } catch (_e) {
      try {
        const res = await fetch(`http://localhost:5000/api/withdrawals?status=${filter}`, {
          headers: { Authorization: 'Bearer dev-token' },
        });
        const data = await res.json();
        if (data.requests) setRequests(data.requests);
      } catch (_err) {}
    } finally {
      setLoading(false);
    }
  };

  const openActionModal = (req: WithdrawalRequest, status: 'APPROVED' | 'REJECTED') => {
    setSelectedRequest(req);
    setActionStatus(status);
    setAdminNote(status === 'REJECTED' ? 'Insufficient verification documentation' : 'Approved for bank payout');
  };

  const handleProcess = async () => {
    if (!selectedRequest) return;
    setLoading(true);
    try {
      const path = actionStatus === 'APPROVED'
        ? `/withdrawals/${selectedRequest.id}/approve`
        : `/withdrawals/${selectedRequest.id}/reject`;

      const data = await apiRequest(path, {
        method: 'PATCH',
        body: JSON.stringify({ adminNote, notifyProducer }),
      }) as { success?: boolean; message?: string };

      if (data && data.success) {
        setSelectedRequest(null);
        await fetchWithdrawals();
      } else {
        alert(data?.message || 'Action completed');
        setSelectedRequest(null);
        await fetchWithdrawals();
      }
    } catch (_e) {
      setRequests(prev => prev.map(r => r.id === selectedRequest.id ? { ...r, status: actionStatus, adminNote } : r));
      setSelectedRequest(null);
    } finally {
      setLoading(false);
    }
  };

  const approvedVolume = requests
    .filter(r => r.status.toUpperCase() === 'APPROVED')
    .reduce((acc, r) => acc + r.amount, 0);

  const pendingVolume = requests
    .filter(r => r.status.toUpperCase() === 'PENDING')
    .reduce((acc, r) => acc + r.amount, 0);

  const stats = {
    pending: requests.filter(r => r.status.toUpperCase() === 'PENDING').length,
    approved: requests.filter(r => r.status.toUpperCase() === 'APPROVED').length,
    rejected: requests.filter(r => r.status.toUpperCase() === 'REJECTED').length,
    totalVolume: approvedVolume,
    pendingVolume: pendingVolume,
  };

  return (
    <div style={{ padding: '24px', fontFamily: 'Inter, system-ui, sans-serif', color: '#111827' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, margin: 0, color: '#111827' }}>Withdrawal Request Management</h1>
          <p style={{ color: '#6b7280', margin: '4px 0 0 0', fontSize: '14px' }}>Review and process payout withdrawal requests submitted by Producers & Investors.</p>
        </div>
        <button
          onClick={fetchWithdrawals}
          style={{
            padding: '8px 16px',
            background: '#047857',
            color: '#fff',
            border: 'none',
            borderRadius: '8px',
            fontWeight: 600,
            cursor: 'pointer',
          }}
        >
          Refresh Requests
        </button>
      </div>

      {/* Stats Overview Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '24px' }}>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>PENDING REQUESTS</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#d97706', marginTop: '4px' }}>{stats.pending}</div>
          <div style={{ fontSize: '11px', color: '#d97706', marginTop: '2px' }}>Vol: ৳{stats.pendingVolume.toLocaleString('en-BD')}</div>
        </div>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>APPROVED PAYOUTS</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#059669', marginTop: '4px' }}>{stats.approved}</div>
        </div>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>REJECTED REQUESTS</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#dc2626', marginTop: '4px' }}>{stats.rejected}</div>
        </div>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>APPROVED PAYOUT VOLUME</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#047857', marginTop: '4px' }}>৳{stats.totalVolume.toLocaleString('en-BD')}</div>
        </div>
      </div>

      {/* Filter Tabs */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '16px' }}>
        {['ALL', 'PENDING', 'APPROVED', 'REJECTED'].map((st) => (
          <button
            key={st}
            onClick={() => setFilter(st)}
            style={{
              padding: '6px 14px',
              borderRadius: '20px',
              border: '1px solid #d1d5db',
              background: filter === st ? '#047857' : '#fff',
              color: filter === st ? '#fff' : '#374151',
              fontSize: '12px',
              fontWeight: 700,
              cursor: 'pointer',
            }}
          >
            {st}
          </button>
        ))}
      </div>

      {/* Table List */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', overflow: 'hidden', border: '1px solid #e5e7eb' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
          <thead>
            <tr style={{ background: '#f9fafb', borderBottom: '1px solid #e5e7eb', color: '#6b7280' }}>
              <th style={{ padding: '12px 16px' }}>Request ID</th>
              <th style={{ padding: '12px 16px' }}>Producer / User</th>
              <th style={{ padding: '12px 16px' }}>Method</th>
              <th style={{ padding: '12px 16px' }}>Account Info</th>
              <th style={{ padding: '12px 16px' }}>Amount</th>
              <th style={{ padding: '12px 16px' }}>Date</th>
              <th style={{ padding: '12px 16px' }}>Status</th>
              <th style={{ padding: '12px 16px' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {requests.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ padding: '24px', textAlign: 'center', color: '#6b7280' }}>
                  {loading ? 'Loading requests...' : 'No withdrawal requests found.'}
                </td>
              </tr>
            ) : (
              requests.map((r) => {
                const isPending = r.status.toUpperCase() === 'PENDING';
                const isApproved = r.status.toUpperCase() === 'APPROVED';
                return (
                  <tr key={r.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '12px 16px', fontWeight: 600 }}>{r.id}</td>
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ fontWeight: 600 }}>{r.producer?.fullName || 'User'}</div>
                      <div style={{ fontSize: '11px', color: '#6b7280' }}>{r.producer?.email}</div>
                    </td>
                    <td style={{ padding: '12px 16px', fontWeight: 600 }}>{r.method}</td>
                    <td style={{ padding: '12px 16px' }}>{r.accountNumber || r.accountDetails?.accountNumber || '—'}</td>
                    <td style={{ padding: '12px 16px', fontWeight: 700, color: '#047857' }}>৳{r.amount.toLocaleString('en-BD')}</td>
                    <td style={{ padding: '12px 16px', color: '#6b7280' }}>{r.requestDate || new Date(r.requestDate || Date.now()).toLocaleDateString()}</td>
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{
                        padding: '4px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: 700,
                        background: isApproved ? '#d1fae5' : isPending ? '#fef3c7' : '#fee2e2',
                        color: isApproved ? '#059669' : isPending ? '#d97706' : '#dc2626',
                      }}>
                        {r.status}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px' }}>
                      {isPending ? (
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button
                            onClick={() => openActionModal(r, 'APPROVED')}
                            style={{ padding: '5px 10px', background: '#047857', color: '#fff', border: 'none', borderRadius: '6px', fontSize: '11px', fontWeight: 600, cursor: 'pointer' }}
                          >
                            Approve
                          </button>
                          <button
                            onClick={() => openActionModal(r, 'REJECTED')}
                            style={{ padding: '5px 10px', background: '#dc2626', color: '#fff', border: 'none', borderRadius: '6px', fontSize: '11px', fontWeight: 600, cursor: 'pointer' }}
                          >
                            Reject
                          </button>
                        </div>
                      ) : (
                        <span style={{ color: '#9ca3af', fontSize: '12px' }}>—</span>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Confirmation / Processing Modal */}
      {selectedRequest && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000
        }}>
          <div style={{ background: '#fff', padding: '24px', borderRadius: '12px', width: '420px', boxShadow: '0 10px 25px rgba(0,0,0,0.2)' }}>
            <h3 style={{ margin: '0 0 12px 0', fontSize: '18px', fontWeight: 700 }}>
              {actionStatus === 'APPROVED' ? 'Approve Withdrawal Request' : 'Reject Withdrawal Request'}
            </h3>
            <p style={{ fontSize: '13px', color: '#4b5563', margin: '0 0 16px 0' }}>
              Confirm {actionStatus.toLowerCase()} of <strong>৳{selectedRequest.amount.toLocaleString()} BDT</strong> payout to {selectedRequest.producer?.fullName}.
            </p>

            <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#374151', marginBottom: '6px' }}>
              Admin Note / Reason
            </label>
            <textarea
              rows={3}
              value={adminNote}
              onChange={(e) => setAdminNote(e.target.value)}
              style={{ width: '100%', padding: '8px', borderRadius: '6px', border: '1px solid #d1d5db', fontSize: '13px', marginBottom: '12px' }}
            />

            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', color: '#374151', marginBottom: '20px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={notifyProducer}
                onChange={(e) => setNotifyProducer(e.target.checked)}
              />
              Notify user via email notification
            </label>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <button
                onClick={() => setSelectedRequest(null)}
                style={{ padding: '8px 14px', background: '#f3f4f6', color: '#374151', border: 'none', borderRadius: '6px', fontSize: '13px', fontWeight: 600, cursor: 'pointer' }}
              >
                Cancel
              </button>
              <button
                onClick={handleProcess}
                style={{
                  padding: '8px 16px',
                  background: actionStatus === 'APPROVED' ? '#047857' : '#dc2626',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  fontSize: '13px',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
              >
                {actionStatus === 'APPROVED' ? 'Confirm Approval' : 'Confirm Rejection'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
