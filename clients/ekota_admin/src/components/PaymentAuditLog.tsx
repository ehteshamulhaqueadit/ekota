import React, { useState, useEffect } from 'react';

export interface PaymentRecord {
  id: string;
  tranId: string;
  valId?: string;
  amount: number | string;
  currency: string;
  paymentType: 'RENT' | 'INVESTMENT';
  status: 'PENDING' | 'VALIDATED' | 'FAILED' | 'CANCELLED';
  cardType?: string;
  user?: {
    fullName: string;
    email: string;
    role: string;
  };
  createdAt: string;
}

const mockPayments: PaymentRecord[] = [
  {
    id: 'pay-01',
    tranId: 'EKOTA-PAY-172312345-101',
    valId: '240808123456789',
    amount: 12500,
    currency: 'BDT',
    paymentType: 'RENT',
    status: 'VALIDATED',
    cardType: 'bKash-BKash',
    user: { fullName: 'Tariq Renter', email: 'tariq@renter.com', role: 'RENTER' },
    createdAt: new Date().toISOString(),
  },
  {
    id: 'pay-02',
    tranId: 'EKOTA-PAY-172312389-204',
    valId: '240808987654321',
    amount: 50000,
    currency: 'BDT',
    paymentType: 'INVESTMENT',
    status: 'VALIDATED',
    cardType: 'VISA-DBBL',
    user: { fullName: 'Salma Investor', email: 'salma@investor.com', role: 'INVESTOR' },
    createdAt: new Date(Date.now() - 3600000 * 5).toISOString(),
  },
  {
    id: 'pay-03',
    tranId: 'EKOTA-PAY-172312411-505',
    amount: 8000,
    currency: 'BDT',
    paymentType: 'RENT',
    status: 'PENDING',
    user: { fullName: 'Karim Renter', email: 'karim@renter.com', role: 'RENTER' },
    createdAt: new Date(Date.now() - 3600000 * 12).toISOString(),
  },
];

export const PaymentAuditLog: React.FC = () => {
  const [payments, setPayments] = useState<PaymentRecord[]>(mockPayments);
  const [filter, setFilter] = useState<string>('ALL');

  useEffect(() => {
    const fetchPayments = async () => {
      try {
        const token = localStorage.getItem('token');
        const res = await fetch('http://localhost:5000/api/payments/admin/all', {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        });
        if (res.ok) {
          const data = await res.json();
          if (data.payments && data.payments.length > 0) {
            setPayments(data.payments);
          }
        }
      } catch (_e) {
        // Fallback mock
      }
    };
    fetchPayments();
  }, []);

  const filteredPayments = filter === 'ALL'
    ? payments
    : payments.filter(p => p.status === filter);

  const totalValidated = payments
    .filter(p => p.status === 'VALIDATED')
    .reduce((sum, p) => sum + Number(p.amount), 0);

  return (
    <div style={{ marginTop: '1.5rem' }}>
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '1rem',
        marginBottom: '1.5rem',
      }}>
        <div className="card" style={{ background: 'rgba(77, 111, 255, 0.1)', border: '1px solid rgba(77, 111, 255, 0.2)' }}>
          <span style={{ fontSize: '0.85rem', color: 'rgba(243, 240, 234, 0.7)' }}>Total Validated Volume</span>
          <h2 style={{ fontSize: '1.8rem', color: '#60a5fa', margin: '0.3rem 0 0' }}>৳{totalValidated.toLocaleString('en-BD')} BDT</h2>
        </div>

        <div className="card" style={{ background: 'rgba(16, 185, 129, 0.1)', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
          <span style={{ fontSize: '0.85rem', color: 'rgba(243, 240, 234, 0.7)' }}>Validated Transactions</span>
          <h2 style={{ fontSize: '1.8rem', color: '#34d399', margin: '0.3rem 0 0' }}>
            {payments.filter(p => p.status === 'VALIDATED').length}
          </h2>
        </div>

        <div className="card" style={{ background: 'rgba(245, 158, 11, 0.1)', border: '1px solid rgba(245, 158, 11, 0.2)' }}>
          <span style={{ fontSize: '0.85rem', color: 'rgba(243, 240, 234, 0.7)' }}>Pending Checkout Sessions</span>
          <h2 style={{ fontSize: '1.8rem', color: '#fbbf24', margin: '0.3rem 0 0' }}>
            {payments.filter(p => p.status === 'PENDING').length}
          </h2>
        </div>
      </div>

      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexWrap: 'wrap',
        gap: '1rem',
        marginBottom: '1rem',
      }}>
        <h2 style={{ margin: 0, fontSize: '1.4rem' }}>SSLCommerz Transaction Audit</h2>

        <div style={{ display: 'flex', gap: '0.5rem' }}>
          {['ALL', 'VALIDATED', 'PENDING', 'FAILED', 'CANCELLED'].map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={filter === f ? '' : 'secondary'}
              style={{ padding: '0.4rem 0.8rem', fontSize: '0.8rem' }}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table style={{
          width: '100%',
          borderCollapse: 'collapse',
          background: 'rgba(16, 19, 29, 0.75)',
          borderRadius: '16px',
          overflow: 'hidden',
          border: '1px solid rgba(243, 240, 234, 0.1)',
        }}>
          <thead>
            <tr style={{ background: 'rgba(255, 255, 255, 0.05)', textAlign: 'left', borderBottom: '1px solid rgba(243, 240, 234, 0.1)' }}>
              <th style={{ padding: '1rem' }}>Transaction ID</th>
              <th style={{ padding: '1rem' }}>User / Payer</th>
              <th style={{ padding: '1rem' }}>Type</th>
              <th style={{ padding: '1rem' }}>Amount</th>
              <th style={{ padding: '1rem' }}>Card / Bank</th>
              <th style={{ padding: '1rem' }}>Status</th>
              <th style={{ padding: '1rem' }}>Date</th>
            </tr>
          </thead>
          <tbody>
            {filteredPayments.map(p => (
              <tr key={p.id} style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.04)' }}>
                <td style={{ padding: '1rem', fontFamily: 'monospace', fontSize: '0.85rem' }}>
                  {p.tranId}
                  {p.valId && (
                    <div style={{ fontSize: '0.75rem', color: 'rgba(243, 240, 234, 0.5)' }}>Val: {p.valId}</div>
                  )}
                </td>
                <td style={{ padding: '1rem' }}>
                  <strong>{p.user?.fullName || 'User'}</strong>
                  <div style={{ fontSize: '0.8rem', color: 'rgba(243, 240, 234, 0.6)' }}>
                    {p.user?.email} ({p.user?.role})
                  </div>
                </td>
                <td style={{ padding: '1rem' }}>
                  <span style={{
                    background: p.paymentType === 'INVESTMENT' ? 'rgba(168, 85, 247, 0.15)' : 'rgba(59, 130, 246, 0.15)',
                    color: p.paymentType === 'INVESTMENT' ? '#c084fc' : '#60a5fa',
                    padding: '0.2rem 0.5rem',
                    borderRadius: '6px',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                  }}>
                    {p.paymentType}
                  </span>
                </td>
                <td style={{ padding: '1rem', fontWeight: 'bold', color: '#f0b36d' }}>
                  ৳{Number(p.amount).toLocaleString('en-BD')} {p.currency}
                </td>
                <td style={{ padding: '1rem', fontSize: '0.85rem', color: 'rgba(243, 240, 234, 0.75)' }}>
                  {p.cardType || 'SSLCommerz Gateway'}
                </td>
                <td style={{ padding: '1rem' }}>
                  <span style={{
                    padding: '0.25rem 0.65rem',
                    borderRadius: '999px',
                    fontSize: '0.78rem',
                    fontWeight: 'bold',
                    background:
                      p.status === 'VALIDATED'
                        ? 'rgba(16, 185, 129, 0.18)'
                        : p.status === 'PENDING'
                        ? 'rgba(245, 158, 11, 0.18)'
                        : 'rgba(239, 68, 68, 0.18)',
                    color:
                      p.status === 'VALIDATED'
                        ? '#34d399'
                        : p.status === 'PENDING'
                        ? '#fbbf24'
                        : '#f87171',
                  }}>
                    {p.status}
                  </span>
                </td>
                <td style={{ padding: '1rem', fontSize: '0.82rem', color: 'rgba(243, 240, 234, 0.6)' }}>
                  {new Date(p.createdAt).toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
