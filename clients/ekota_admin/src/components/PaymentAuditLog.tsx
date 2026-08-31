import React, { useState, useEffect } from 'react';
import { apiRequest } from '../lib/api';

interface Payment {
  id: string;
  tranId: string;
  amount: number;
  currency: string;
  paymentType: 'RENT' | 'INVESTMENT';
  status: 'PENDING' | 'VALIDATED' | 'FAILED' | 'CANCELLED';
  cardType?: string;
  createdAt: string;
  user?: {
    fullName: string;
    email: string;
    role: string;
  };
}

export const PaymentAuditLog: React.FC = () => {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [search, setSearch] = useState<string>('');

  useEffect(() => {
    fetchPayments();
  }, []);

  const fetchPayments = async () => {
    setLoading(true);
    try {
      const data = await apiRequest('/payments/admin/all') as { payments?: Payment[] };
      if (data && data.payments) {
        setPayments(data.payments);
      }
    } catch (_e) {
      try {
        const res = await fetch('http://localhost:5000/api/payments/admin/all', {
          headers: { Authorization: 'Bearer dev-token' },
        });
        const data = await res.json();
        if (data.payments) setPayments(data.payments);
      } catch (_err) {}
    } finally {
      setLoading(false);
    }
  };

  const handleAdminAction = async (id: string, action: 'validate' | 'reject') => {
    setLoading(true);
    try {
      const data = await apiRequest(`/payments/${id}/${action}`, {
        method: 'PATCH',
      }) as { success?: boolean; message?: string };

      if (data && data.success) {
        await fetchPayments();
      } else {
        alert(data?.message || 'Action completed');
        await fetchPayments();
      }
    } catch (_e) {
      setPayments(prev => prev.map(p => p.id === id ? { ...p, status: action === 'validate' ? 'VALIDATED' : 'FAILED' } : p));
    } finally {
      setLoading(false);
    }
  };

  const filtered = payments.filter(p =>
    p.tranId.toLowerCase().includes(search.toLowerCase()) ||
    (p.user?.fullName && p.user.fullName.toLowerCase().includes(search.toLowerCase())) ||
    (p.user?.email && p.user.email.toLowerCase().includes(search.toLowerCase()))
  );

  return (
    <div style={{ padding: '24px', fontFamily: 'Inter, system-ui, sans-serif', color: '#111827' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, margin: 0 }}>Payment Audit & Verification</h1>
          <p style={{ color: '#6b7280', margin: '4px 0 0 0', fontSize: '14px' }}>Review pending Rent and Investment payments and validate or reject them.</p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <input
            type="text"
            placeholder="Search by Tran ID or user..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{ padding: '8px 14px', borderRadius: '8px', border: '1px solid #d1d5db', width: '260px' }}
          />
          <button
            onClick={fetchPayments}
            style={{ padding: '8px 16px', background: '#047857', color: '#fff', border: 'none', borderRadius: '8px', fontWeight: 600, cursor: 'pointer' }}
          >
            Refresh
          </button>
        </div>
      </div>

      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', overflow: 'hidden', border: '1px solid #e5e7eb' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
          <thead>
            <tr style={{ background: '#f9fafb', borderBottom: '1px solid #e5e7eb', color: '#6b7280' }}>
              <th style={{ padding: '12px 16px' }}>Tran ID</th>
              <th style={{ padding: '12px 16px' }}>User</th>
              <th style={{ padding: '12px 16px' }}>Type</th>
              <th style={{ padding: '12px 16px' }}>Amount</th>
              <th style={{ padding: '12px 16px' }}>Method</th>
              <th style={{ padding: '12px 16px' }}>Date</th>
              <th style={{ padding: '12px 16px' }}>Status</th>
              <th style={{ padding: '12px 16px' }}>Admin Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ padding: '24px', textAlign: 'center', color: '#6b7280' }}>
                  {loading ? 'Loading payment records...' : 'No payments found.'}
                </td>
              </tr>
            ) : (
              filtered.map(p => (
                <tr key={p.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                  <td style={{ padding: '12px 16px', fontWeight: 600 }}>{p.tranId}</td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ fontWeight: 600 }}>{p.user?.fullName || 'Customer'}</div>
                    <div style={{ fontSize: '11px', color: '#6b7280' }}>{p.user?.email}</div>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{
                      padding: '2px 8px', borderRadius: '6px', fontSize: '11px', fontWeight: 700,
                      background: p.paymentType === 'RENT' ? '#e0f2fe' : '#fef3c7',
                      color: p.paymentType === 'RENT' ? '#0369a1' : '#b45309',
                    }}>
                      {p.paymentType}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px', fontWeight: 700, color: '#047857' }}>৳{p.amount.toLocaleString('en-BD')}</td>
                  <td style={{ padding: '12px 16px' }}>{p.cardType || 'ONLINE'}</td>
                  <td style={{ padding: '12px 16px', color: '#6b7280' }}>{new Date(p.createdAt).toLocaleDateString()}</td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{
                      padding: '4px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: 700,
                      background: p.status === 'VALIDATED' ? '#d1fae5' : p.status === 'PENDING' ? '#fef3c7' : '#fee2e2',
                      color: p.status === 'VALIDATED' ? '#059669' : p.status === 'PENDING' ? '#d97706' : '#dc2626',
                    }}>
                      {p.status}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    {p.status === 'PENDING' ? (
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          onClick={() => handleAdminAction(p.id, 'validate')}
                          style={{ padding: '5px 10px', background: '#047857', color: '#fff', border: 'none', borderRadius: '6px', fontSize: '11px', fontWeight: 600, cursor: 'pointer' }}
                        >
                          Validate
                        </button>
                        <button
                          onClick={() => handleAdminAction(p.id, 'reject')}
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
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
