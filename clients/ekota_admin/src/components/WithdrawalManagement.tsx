import React, { useState, useEffect } from 'react';

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
  const [adminNote, setAdminNote] = useState<string>('');
  const [notifyProducer, setNotifyProducer] = useState<boolean>(true);

  useEffect(() => {
    fetchWithdrawals();
  }, [filter]);

  const fetchWithdrawals = async () => {
    setLoading(true);
    try {
      const response = await fetch(`/api/withdrawals?status=${filter}`);
      const data = await response.json();
      if (data.success && data.requests) {
        setRequests(data.requests);
      }
    } catch (_e) {
      // Fallback mock data for admin standalone preview
      setRequests([
        {
          id: 'WD-8921',
          producerId: 'prod-01',
          producer: {
            id: 'prod-01',
            fullName: 'Nilufar Rashidova',
            email: 'nilufar@ekota.com.bd',
            phoneNumber: '01711-223344',
            kycStatus: 'VERIFIED',
            avatarInitials: 'NR',
          },
          amount: 45000,
          method: 'BKASH',
          accountNumber: '01711-223344',
          walletBalance: 245000,
          requestDate: 'Aug 8, 2026',
          status: 'PENDING',
        },
        {
          id: 'WD-7810',
          producerId: 'prod-02',
          producer: {
            id: 'prod-02',
            fullName: 'Tanvir Hossain',
            email: 'tanvir@ekota.com.bd',
            phoneNumber: '01822-334455',
            kycStatus: 'VERIFIED',
            avatarInitials: 'TH',
          },
          amount: 120000,
          method: 'BANK_TRANSFER',
          accountNumber: '1501203498001 (City Bank)',
          walletBalance: 120000,
          requestDate: 'Aug 5, 2026',
          status: 'APPROVED',
          processedAt: 'Aug 6, 2026',
          transactionRef: 'TXN-EKT-991823',
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const handleAction = async (actionStatus: 'APPROVED' | 'REJECTED') => {
    if (!selectedRequest) return;
    setLoading(true);
    try {
      const endpoint = actionStatus === 'APPROVED'
        ? `/api/withdrawals/${selectedRequest.id}/approve`
        : `/api/withdrawals/${selectedRequest.id}/reject`;

      const response = await fetch(endpoint, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ adminNote, notifyProducer }),
      });

      const data = await response.json();
      if (data.success) {
        setSelectedRequest(null);
        fetchWithdrawals();
      } else {
        alert(data.message || 'Action failed');
      }
    } catch (_e) {
      // Local optimistic state update for demo
      setRequests(prev => prev.map(r => r.id === selectedRequest.id ? { ...r, status: actionStatus, adminNote } : r));
      setSelectedRequest(null);
    } finally {
      setLoading(false);
    }
  };

  const stats = {
    pending: requests.filter(r => r.status.toUpperCase() === 'PENDING').length,
    approved: requests.filter(r => r.status.toUpperCase() === 'APPROVED').length,
    rejected: requests.filter(r => r.status.toUpperCase() === 'REJECTED').length,
    totalVolume: requests.reduce((acc, r) => acc + r.amount, 0),
  };

  return (
    <div style={{ padding: '24px', fontFamily: 'Inter, system-ui, sans-serif', color: '#111827' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, margin: 0, color: '#111827' }}>Withdrawal Request Management</h1>
          <p style={{ color: '#6b7280', margin: '4px 0 0 0', fontSize: '14px' }}>Review and process payout withdrawal requests submitted by Producers.</p>
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
        </div>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>APPROVED PAYOUTS</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#059669', marginTop: '4px' }}>{stats.approved}</div>
        </div>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>REJECTED</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#dc2626', marginTop: '4px' }}>{stats.rejected}</div>
        </div>
        <div style={{ background: '#fff', padding: '16px', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', border: '1px solid #e5e7eb' }}>
          <div style={{ fontSize: '12px', color: '#6b7280', fontWeight: 600 }}>TOTAL VOLUME</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: '#111827', marginTop: '4px' }}>৳{stats.totalVolume.toLocaleString('en-BD')}</div>
        </div>
      </div>

      {/* Filter Tabs */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '16px' }}>
        {['ALL', 'PENDING', 'APPROVED', 'REJECTED'].map(st => (
          <button
            key={st}
            onClick={() => setFilter(st)}
            style={{
              padding: '8px 16px',
              borderRadius: '8px',
              border: 'none',
              fontWeight: 600,
              fontSize: '13px',
              cursor: 'pointer',
              background: filter === st ? '#047857' : '#e5e7eb',
              color: filter === st ? '#ffffff' : '#374151',
            }}
          >
            {st}
          </button>
        ))}
      </div>

      {/* Table */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', overflow: 'hidden', border: '1px solid #e5e7eb' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
          <thead>
            <tr style={{ background: '#f9fafb', borderBottom: '1px solid #e5e7eb', color: '#6b7280' }}>
              <th style={{ padding: '12px 16px' }}>ID</th>
              <th style={{ padding: '12px 16px' }}>Producer</th>
              <th style={{ padding: '12px 16px' }}>Amount</th>
              <th style={{ padding: '12px 16px' }}>Method</th>
              <th style={{ padding: '12px 16px' }}>Account</th>
              <th style={{ padding: '12px 16px' }}>Date</th>
              <th style={{ padding: '12px 16px' }}>Status</th>
              <th style={{ padding: '12px 16px' }}>Action</th>
            </tr>
          </thead>
          <tbody>
            {requests.map(r => (
              <tr key={r.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                <td style={{ padding: '12px 16px', fontWeight: 600 }}>{r.id}</td>
                <td style={{ padding: '12px 16px' }}>
                  <div style={{ fontWeight: 600 }}>{r.producer?.fullName}</div>
                  <div style={{ fontSize: '11px', color: '#6b7280' }}>{r.producer?.email}</div>
                </td>
                <td style={{ padding: '12px 16px', fontWeight: 700, color: '#047857' }}>৳{r.amount.toLocaleString('en-BD')}</td>
                <td style={{ padding: '12px 16px' }}>{r.method}</td>
                <td style={{ padding: '12px 16px' }}>{r.accountNumber}</td>
                <td style={{ padding: '12px 16px', color: '#6b7280' }}>{r.requestDate}</td>
                <td style={{ padding: '12px 16px' }}>
                  <span style={{
                    padding: '4px 8px',
                    borderRadius: '12px',
                    fontSize: '11px',
                    fontWeight: 700,
                    background: r.status.toUpperCase() === 'PENDING' ? '#fef3c7' : r.status.toUpperCase() === 'APPROVED' ? '#d1fae5' : '#fee2e2',
                    color: r.status.toUpperCase() === 'PENDING' ? '#d97706' : r.status.toUpperCase() === 'APPROVED' ? '#059669' : '#dc2626',
                  }}>
                    {r.status.toUpperCase()}
                  </span>
                </td>
                <td style={{ padding: '12px 16px' }}>
                  {r.status.toUpperCase() === 'PENDING' ? (
                    <button
                      onClick={() => {
                        setSelectedRequest(r);
                        setAdminNote(r.adminNote || '');
                      }}
                      style={{
                        padding: '6px 12px',
                        background: '#047857',
                        color: '#fff',
                        border: 'none',
                        borderRadius: '6px',
                        fontWeight: 600,
                        cursor: 'pointer',
                      }}
                    >
                      Review
                    </button>
                  ) : (
                    <span style={{ color: '#9ca3af' }}>—</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Review Modal */}
      {selectedRequest && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000
        }}>
          <div style={{ background: '#fff', borderRadius: '12px', maxWidth: '420px', width: '100%', padding: '24px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 16px 0', fontSize: '18px', fontWeight: 700 }}>Review Withdrawal Request</h3>
            <div style={{ background: '#f9fafb', padding: '12px', borderRadius: '8px', marginBottom: '16px', fontSize: '13px' }}>
              <div><strong>Producer:</strong> {selectedRequest.producer?.fullName}</div>
              <div><strong>Amount:</strong> ৳{selectedRequest.amount.toLocaleString('en-BD')}</div>
              <div><strong>Method:</strong> {selectedRequest.method}</div>
              <div><strong>Account:</strong> {selectedRequest.accountNumber}</div>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, marginBottom: '4px' }}>ADMIN NOTE / REASON</label>
              <textarea
                value={adminNote}
                onChange={e => setAdminNote(e.target.value)}
                placeholder="Enter notes or reason for producer..."
                rows={3}
                style={{ width: '100%', padding: '8px', borderRadius: '6px', border: '1px solid #d1d5db', boxSizing: 'border-box' }}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', gap: '12px' }}>
              <button
                onClick={() => setSelectedRequest(null)}
                style={{ padding: '8px 16px', background: '#e5e7eb', border: 'none', borderRadius: '6px', fontWeight: 600, cursor: 'pointer' }}
              >
                Cancel
              </button>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button
                  disabled={loading}
                  onClick={() => handleAction('REJECTED')}
                  style={{ padding: '8px 16px', background: '#dc2626', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: 600, cursor: 'pointer' }}
                >
                  Reject
                </button>
                <button
                  disabled={loading}
                  onClick={() => handleAction('APPROVED')}
                  style={{ padding: '8px 16px', background: '#047857', color: '#fff', border: 'none', borderRadius: '6px', fontWeight: 600, cursor: 'pointer' }}
                >
                  Approve & Pay
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
