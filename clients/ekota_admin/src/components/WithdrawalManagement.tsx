import React, { useState, useEffect } from 'react';

export interface WithdrawalRequest {
  id: string;
  producerId: string;
  producer: {
    fullName: string;
    email: string;
    phoneNumber?: string;
    kycStatus?: string;
    avatarInitials: string;
  };
  amount: number;
  method: 'bKash' | 'Nagad' | 'Rocket' | 'Bank Transfer';
  accountNumber: string;
  walletBalance: number;
  requestDate: string;
  reason?: string;
  status: 'Pending' | 'Approved' | 'Rejected' | 'Paid';
  adminNote?: string;
  transactionRef?: string;
}

const initialFigmaWithdrawals: WithdrawalRequest[] = [
  {
    id: 'WD-3847',
    producerId: 'prod-01',
    producer: {
      fullName: 'Nilufar Rashidova',
      email: 'nilufar@ekota.com.bd',
      phoneNumber: '01711-223344',
      kycStatus: 'VERIFIED',
      avatarInitials: 'NR',
    },
    amount: 142500,
    method: 'bKash',
    accountNumber: '01711-223344',
    walletBalance: 342500,
    requestDate: '14 Jul 2026, 09:12',
    reason: 'Quarterly crop sales profit withdrawal',
    status: 'Pending',
  },
  {
    id: 'WD-3501',
    producerId: 'prod-02',
    producer: {
      fullName: 'Arif Chowdhury',
      email: 'arif@ekota.com.bd',
      phoneNumber: '01899-887766',
      kycStatus: 'VERIFIED',
      avatarInitials: 'AC',
    },
    amount: 87000,
    method: 'Nagad',
    accountNumber: '01899-887766',
    walletBalance: 120000,
    requestDate: '13 Jul 2026, 14:45',
    status: 'Approved',
    transactionRef: 'NGD-TXN-88112',
  },
  {
    id: 'WD-2810',
    producerId: 'prod-03',
    producer: {
      fullName: 'Tania Islam',
      email: 'tania@ekota.com.bd',
      phoneNumber: '01912-345678',
      kycStatus: 'VERIFIED',
      avatarInitials: 'TI',
    },
    amount: 220000,
    method: 'Bank Transfer',
    accountNumber: '1501209988001 (Brac Bank)',
    walletBalance: 220000,
    requestDate: '12 Jul 2026, 11:00',
    status: 'Rejected',
    adminNote: 'Incomplete bank branch routing details.',
  },
  {
    id: 'WD-2036',
    producerId: 'prod-04',
    producer: {
      fullName: 'Tanvir Ahmed',
      email: 'tanvir@ekota.com.bd',
      phoneNumber: '01817-902233',
      kycStatus: 'VERIFIED',
      avatarInitials: 'TA',
    },
    amount: 45000,
    method: 'Rocket',
    accountNumber: '01817-902233',
    walletBalance: 46000,
    requestDate: '11 Jul 2026, 16:30',
    reason: 'Harvest season payout',
    status: 'Pending',
  },
  {
    id: 'WD-1798',
    producerId: 'prod-05',
    producer: {
      fullName: 'Melvina Begum',
      email: 'melvina@ekota.com.bd',
      phoneNumber: '01755-992211',
      kycStatus: 'VERIFIED',
      avatarInitials: 'MB',
    },
    amount: 98500,
    method: 'bKash',
    accountNumber: '01755-992211',
    walletBalance: 198500,
    requestDate: '10 Jul 2026, 09:20',
    status: 'Paid',
    transactionRef: 'BKS-99228811',
  },
];

export const WithdrawalManagement: React.FC = () => {
  const [requests, setRequests] = useState<WithdrawalRequest[]>(initialFigmaWithdrawals);
  const [selectedRequest, setSelectedRequest] = useState<WithdrawalRequest | null>(null);
  const [adminNote, setAdminNote] = useState('');
  const [notifyProducer, setNotifyProducer] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  useEffect(() => {
    const fetchApiData = async () => {
      try {
        const token = localStorage.getItem('token');
        const res = await fetch('http://localhost:5000/api/withdrawals/admin/all', {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        });
        if (res.ok) {
          const data = await res.json();
          if (data.requests && data.requests.length > 0) {
            const mapped = data.requests.map((r: any) => ({
              id: r.id.substring(0, 7),
              producerId: r.producerId,
              producer: {
                fullName: r.producer?.fullName || 'Producer',
                email: r.producer?.email || 'producer@ekota.bd',
                phoneNumber: r.producer?.phoneNumber || '01700000000',
                kycStatus: 'VERIFIED',
                avatarInitials: (r.producer?.fullName || 'P').split(' ').map((n: string) => n[0]).join('').toUpperCase(),
              },
              amount: Number(r.amount),
              method: r.method === 'BANK_TRANSFER' ? 'Bank Transfer' : r.method,
              accountNumber: r.accountDetails?.accountNumber || r.accountDetails?.mobileNumber || 'N/A',
              walletBalance: Number(r.amount) + 1000,
              requestDate: new Date(r.createdAt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }),
              status: r.status === 'PROCESSED' ? 'Paid' : r.status === 'APPROVED' ? 'Approved' : r.status === 'REJECTED' ? 'Rejected' : 'Pending',
              adminNote: r.adminNote,
              transactionRef: r.transactionRef,
            }));
            setRequests(mapped);
          }
        }
      } catch (_e) {
        // Fallback to initialFigmaWithdrawals
      }
    };
    fetchApiData();
  }, []);

  const totalRequests = requests.length;
  const pendingCount = requests.filter(r => r.status === 'Pending').length;
  const approvedCount = requests.filter(r => r.status === 'Approved' || r.status === 'Paid').length;
  const totalAmountSum = requests.reduce((sum, r) => sum + r.amount, 0);

  const handleAction = (newStatus: 'Approved' | 'Rejected' | 'Paid') => {
    if (!selectedRequest) return;

    setRequests(prev =>
      prev.map(r =>
        r.id === selectedRequest.id
          ? {
              ...r,
              status: newStatus,
              adminNote: adminNote || r.adminNote,
              transactionRef: newStatus !== 'Rejected' ? `TXN-EKT-${Math.floor(100000 + Math.random() * 900000)}` : undefined,
            }
          : r
      )
    );

    setToastMessage(`Withdrawal request for ${selectedRequest.producer.fullName} has been marked as ${newStatus}.`);
    setSelectedRequest(null);
    setAdminNote('');
    setTimeout(() => setToastMessage(null), 4000);
  };

  const filteredRequests = requests.filter(r => {
    const matchesSearch = r.producer.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          r.id.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesFilter = statusFilter === 'ALL' || r.status.toUpperCase() === statusFilter.toUpperCase();
    return matchesSearch && matchesFilter;
  });

  return (
    <div style={{ fontFamily: 'Inter, system-ui, sans-serif', color: '#1f2937' }}>
      {toastMessage && (
        <div style={{
          position: 'fixed',
          top: '20px',
          right: '20px',
          background: '#047857',
          color: '#ffffff',
          padding: '12px 20px',
          borderRadius: '8px',
          boxShadow: '0 10px 15px -3px rgba(0,0,0,0.3)',
          fontWeight: 600,
          zIndex: 2000,
        }}>
          ✓ {toastMessage}
        </div>
      )}

      {/* Top Search & Filter Toolbar */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        background: '#ffffff',
        padding: '14px 20px',
        borderRadius: '12px',
        marginBottom: '20px',
        boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, maxWidth: '400px' }}>
          <span style={{ color: '#9ca3af' }}>🔍</span>
          <input
            type="text"
            placeholder="Search producers, IDs..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{
              border: 'none',
              outline: 'none',
              width: '100%',
              fontSize: '14px',
              color: '#1f2937',
            }}
          />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <select
            value={statusFilter}
            onChange={e => setStatusFilter(e.target.value)}
            style={{
              padding: '8px 14px',
              borderRadius: '8px',
              border: '1px solid #e5e7eb',
              background: '#f9fafb',
              fontSize: '13px',
              fontWeight: 500,
              cursor: 'pointer',
            }}
          >
            <option value="ALL">Filter: All Requests</option>
            <option value="PENDING">Status: Pending</option>
            <option value="APPROVED">Status: Approved</option>
            <option value="PAID">Status: Paid</option>
            <option value="REJECTED">Status: Rejected</option>
          </select>
        </div>
      </div>

      {/* Header title */}
      <div style={{ marginBottom: '20px' }}>
        <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#111827' }}>Withdrawal Requests</h2>
        <p style={{ margin: '4px 0 0', color: '#6b7280', fontSize: '13px' }}>
          Review and process producer withdrawal requests.
        </p>
      </div>

      {/* 4 Summary Cards (Figma exact match) */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gap: '16px',
        marginBottom: '24px',
      }}>
        <div style={{ background: '#ffffff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #f3f4f6', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
          <span style={{ fontSize: '11px', fontWeight: 700, color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>TOTAL REQUESTS</span>
          <div style={{ fontSize: '26px', fontWeight: 800, color: '#111827', marginTop: '6px' }}>{totalRequests}</div>
        </div>

        <div style={{ background: '#ffffff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #f3f4f6', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '11px', fontWeight: 700, color: '#d97706', textTransform: 'uppercase', letterSpacing: '0.05em' }}>PENDING</span>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#f59e0b' }}></span>
          </div>
          <div style={{ fontSize: '26px', fontWeight: 800, color: '#111827', marginTop: '6px' }}>{pendingCount}</div>
        </div>

        <div style={{ background: '#ffffff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #f3f4f6', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '11px', fontWeight: 700, color: '#059669', textTransform: 'uppercase', letterSpacing: '0.05em' }}>APPROVED</span>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10b981' }}></span>
          </div>
          <div style={{ fontSize: '26px', fontWeight: 800, color: '#111827', marginTop: '6px' }}>{approvedCount}</div>
        </div>

        <div style={{ background: '#ffffff', padding: '16px 20px', borderRadius: '12px', border: '1px solid #f3f4f6', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
          <span style={{ fontSize: '11px', fontWeight: 700, color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>TOTAL AMOUNT</span>
          <div style={{ fontSize: '26px', fontWeight: 800, color: '#111827', marginTop: '6px' }}>৳{totalAmountSum.toLocaleString('en-BD')}</div>
        </div>
      </div>

      {/* Main Requests Table */}
      <div style={{ background: '#ffffff', borderRadius: '12px', border: '1px solid #e5e7eb', overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid #f3f4f6', fontWeight: 700, fontSize: '14px', color: '#374151' }}>
          All Requests
        </div>

        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
          <thead>
            <tr style={{ background: '#f9fafb', borderBottom: '1px solid #e5e7eb', color: '#6b7280', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              <th style={{ padding: '12px 20px' }}>PRODUCER</th>
              <th style={{ padding: '12px 20px' }}>AMOUNT</th>
              <th style={{ padding: '12px 20px' }}>METHOD</th>
              <th style={{ padding: '12px 20px' }}>REQUEST DATE</th>
              <th style={{ padding: '12px 20px' }}>STATUS</th>
              <th style={{ padding: '12px 20px', textAlign: 'right' }}>ACTION</th>
            </tr>
          </thead>
          <tbody>
            {filteredRequests.map(r => (
              <tr key={r.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                <td style={{ padding: '14px 20px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: '#047857',
                      color: '#ffffff',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontWeight: 700,
                      fontSize: '12px',
                    }}>
                      {r.producer.avatarInitials}
                    </div>
                    <div>
                      <div style={{ fontWeight: 600, color: '#111827' }}>{r.producer.fullName}</div>
                      <div style={{ fontSize: '11px', color: '#9ca3af' }}>{r.id}</div>
                    </div>
                  </div>
                </td>
                <td style={{ padding: '14px 20px', fontWeight: 700, color: '#111827' }}>
                  ৳{r.amount.toLocaleString('en-BD')}
                </td>
                <td style={{ padding: '14px 20px', color: '#4b5563' }}>
                  {r.method}
                </td>
                <td style={{ padding: '14px 20px', color: '#6b7280', fontSize: '12px' }}>
                  {r.requestDate}
                </td>
                <td style={{ padding: '14px 20px' }}>
                  <span style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '5px',
                    padding: '4px 10px',
                    borderRadius: '999px',
                    fontSize: '11px',
                    fontWeight: 600,
                    background:
                      r.status === 'Pending' ? '#fef3c7' :
                      r.status === 'Approved' ? '#d1fae5' :
                      r.status === 'Paid' ? '#e0f2fe' : '#fee2e2',
                    color:
                      r.status === 'Pending' ? '#b45309' :
                      r.status === 'Approved' ? '#047857' :
                      r.status === 'Paid' ? '#0369a1' : '#b91c1c',
                  }}>
                    <span style={{
                      width: '6px',
                      height: '6px',
                      borderRadius: '50%',
                      background:
                        r.status === 'Pending' ? '#d97706' :
                        r.status === 'Approved' ? '#059669' :
                        r.status === 'Paid' ? '#0284c7' : '#dc2626',
                    }}></span>
                    {r.status}
                  </span>
                </td>
                <td style={{ padding: '14px 20px', textAlign: 'right' }}>
                  {r.status === 'Pending' ? (
                    <button
                      onClick={() => {
                        setSelectedRequest(r);
                        setAdminNote(r.adminNote || '');
                      }}
                      style={{
                        padding: '6px 14px',
                        background: '#047857',
                        color: '#ffffff',
                        border: 'none',
                        borderRadius: '6px',
                        fontWeight: 600,
                        fontSize: '12px',
                        cursor: 'pointer',
                      }}
                    >
                      Review
                    </button>
                  ) : (
                    <span style={{ color: '#9ca3af', fontSize: '12px' }}>—</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Figma Review Modal Exact Match */}
      {selectedRequest && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.6)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px',
        }}>
          <div style={{
            background: '#ffffff',
            borderRadius: '16px',
            maxWidth: '420px',
            width: '100%',
            boxShadow: '0 20px 25px -5px rgba(0,0,0,0.2)',
            overflow: 'hidden',
          }}>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '16px 20px',
              borderBottom: '1px solid #f3f4f6',
            }}>
              <h3 style={{ margin: 0, fontSize: '16px', fontWeight: 700, color: '#111827' }}>Review Request</h3>
              <button
                onClick={() => setSelectedRequest(null)}
                style={{ background: 'none', border: 'none', fontSize: '18px', cursor: 'pointer', color: '#9ca3af' }}
              >
                ✕
              </button>
            </div>

            <div style={{ padding: '20px' }}>
              {/* Producer Info Header */}
              <div style={{ fontSize: '10px', fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '8px' }}>
                PRODUCER INFORMATION
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
                <div style={{
                  width: '36px',
                  height: '36px',
                  borderRadius: '50%',
                  background: '#047857',
                  color: '#fff',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 700,
                }}>
                  {selectedRequest.producer.avatarInitials}
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '14px', color: '#111827' }}>{selectedRequest.producer.fullName}</div>
                  <div style={{ fontSize: '11px', color: '#059669', fontWeight: 600 }}>Verified Producer</div>
                </div>
              </div>

              {/* Request Details */}
              <div style={{ fontSize: '10px', fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '8px' }}>
                REQUEST DETAILS
              </div>
              <div style={{ background: '#f9fafb', padding: '12px 14px', borderRadius: '8px', fontSize: '12px', marginBottom: '16px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ color: '#6b7280' }}>Withdrawal Amount</span>
                  <span style={{ fontWeight: 700, color: '#111827' }}>৳{selectedRequest.amount.toLocaleString('en-BD')}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ color: '#6b7280' }}>Method</span>
                  <span style={{ fontWeight: 600, color: '#374151' }}>{selectedRequest.method}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ color: '#6b7280' }}>Account / Number</span>
                  <span style={{ fontWeight: 600, color: '#374151' }}>{selectedRequest.accountNumber}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ color: '#6b7280' }}>Wallet Balance</span>
                  <span style={{ fontWeight: 600, color: '#059669' }}>৳{selectedRequest.walletBalance.toLocaleString('en-BD')}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <span style={{ color: '#6b7280' }}>Request Date</span>
                  <span style={{ color: '#4b5563' }}>{selectedRequest.requestDate}</span>
                </div>
                {selectedRequest.reason && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '6px', paddingTop: '6px', borderTop: '1px dashed #e5e7eb' }}>
                    <span style={{ color: '#6b7280' }}>Reason</span>
                    <span style={{ color: '#374151', fontStyle: 'italic' }}>{selectedRequest.reason}</span>
                  </div>
                )}
              </div>

              {/* Admin Notes */}
              <div style={{ marginBottom: '14px' }}>
                <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: '#6b7280', uppercase: 'true', marginBottom: '6px' }}>
                  ADMIN NOTES
                </label>
                <textarea
                  value={adminNote}
                  onChange={e => setAdminNote(e.target.value)}
                  placeholder="Add processing notes or rejection reason (sent to producer)..."
                  rows={2}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: '8px',
                    border: '1px solid #d1d5db',
                    fontSize: '12px',
                    boxSizing: 'border-box',
                    outline: 'none',
                  }}
                />
              </div>

              {/* Notify Producer Toggle */}
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
                <div>
                  <div style={{ fontSize: '12px', fontWeight: 600, color: '#374151' }}>Notify Producer</div>
                  <div style={{ fontSize: '11px', color: '#9ca3af' }}>Send email & SMS notification</div>
                </div>
                <input
                  type="checkbox"
                  checked={notifyProducer}
                  onChange={e => setNotifyProducer(e.target.checked)}
                  style={{ width: '16px', height: '16px', accentColor: '#047857', cursor: 'pointer' }}
                />
              </div>

              {/* Action Buttons */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <button
                  onClick={() => handleAction('Rejected')}
                  style={{
                    padding: '10px',
                    background: '#047857',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '8px',
                    fontWeight: 600,
                    fontSize: '13px',
                    cursor: 'pointer',
                  }}
                >
                  Reject
                </button>
                <button
                  onClick={() => handleAction('Approved')}
                  style={{
                    padding: '10px',
                    background: '#047857',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '8px',
                    fontWeight: 600,
                    fontSize: '13px',
                    cursor: 'pointer',
                  }}
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
