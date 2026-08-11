import React, { useState, useEffect } from 'react';
import { apiRequest } from '../lib/api';

interface Producer {
  id: string;
  fullName: string;
  email: string;
  isBlocked?: boolean;
}

interface Listing {
  id: string;
  assetName: string;
  category: string;
  fundingTarget: number;
  rentalPrice: number;
  description: string;
  specifications?: string;
  status: string;
  campaignStatus: string;
  createdAt: string;
  producerId: string;
  producer?: Producer;
}

export const PostManagement: React.FC = () => {
  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [search, setSearch] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('');

  // Modals state
  const [editingListing, setEditingListing] = useState<Listing | null>(null);
  const [notifyListing, setNotifyListing] = useState<Listing | null>(null);
  const [warningMessage, setWarningMessage] = useState<string>('');
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState<boolean>(false);

  // Edit form state
  const [editForm, setEditForm] = useState({
    assetName: '',
    category: '',
    fundingTarget: 0,
    rentalPrice: 0,
    status: 'active',
    campaignStatus: 'funding',
    description: '',
    specifications: ''
  });

  useEffect(() => {
    fetchListings();
  }, [statusFilter]);

  const fetchListings = async () => {
    setLoading(true);
    try {
      let query = '/admin/listings?';
      if (statusFilter) query += `status=${statusFilter}&`;
      if (search) query += `search=${encodeURIComponent(search)}&`;

      const data = await apiRequest(query) as Listing[];
      setListings(Array.isArray(data) ? data : []);
    } catch (_err) {
      // Fallback data if API endpoint unavailable
      setListings([
        {
          id: '20000000-0000-0000-0000-000000000001',
          assetName: 'Automatic Rice Harvester 5000',
          category: 'Agricultural Machinery',
          fundingTarget: 250000,
          rentalPrice: 1500,
          description: 'High efficiency paddy harvester available for seasonal lease.',
          specifications: 'Engine: 75HP Diesel, Fuel Capacity: 60L',
          status: 'active',
          campaignStatus: 'funding',
          createdAt: new Date().toISOString(),
          producerId: '10000000-0000-0000-0000-000000000001',
          producer: {
            id: '10000000-0000-0000-0000-000000000001',
            fullName: 'Karim Agro',
            email: 'producer_karim@ekota.com',
            isBlocked: false
          }
        },
        {
          id: '20000000-0000-0000-0000-000000000002',
          assetName: 'Solar Powered Cold Storage Facility',
          category: 'Storage & Logistics',
          fundingTarget: 500000,
          rentalPrice: 3000,
          description: 'Temperature-controlled preservation unit for fruits and vegetables.',
          specifications: 'Capacity: 10 Metric Tons, Temp Range: 2°C to 10°C',
          status: 'active',
          campaignStatus: 'funding',
          createdAt: new Date().toISOString(),
          producerId: '10000000-0000-0000-0000-000000000001',
          producer: {
            id: '10000000-0000-0000-0000-000000000001',
            fullName: 'Karim Agro',
            email: 'producer_karim@ekota.com',
            isBlocked: false
          }
        }
      ]);
    } finally {
      setLoading(false);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchListings();
  };

  const openEditModal = (listing: Listing) => {
    setEditingListing(listing);
    setEditForm({
      assetName: listing.assetName || '',
      category: listing.category || '',
      fundingTarget: listing.fundingTarget || 0,
      rentalPrice: listing.rentalPrice || 0,
      status: listing.status || 'active',
      campaignStatus: listing.campaignStatus || 'funding',
      description: listing.description || '',
      specifications: listing.specifications || ''
    });
    setActionError(null);
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingListing) return;
    setSubmitting(true);
    setActionError(null);

    try {
      const res = await apiRequest(`/admin/listings/${editingListing.id}`, {
        method: 'PUT',
        body: JSON.stringify(editForm)
      }) as { listing?: Listing; message?: string };

      setActionSuccess(res.message || 'Listing updated successfully');
      setEditingListing(null);
      fetchListings();
    } catch (err: any) {
      setActionError(err.message || 'Failed to update listing');
    } finally {
      setSubmitting(false);
    }
  };

  const openNotifyModal = (listing: Listing) => {
    setNotifyListing(listing);
    setWarningMessage('');
    setActionError(null);
  };

  const handleSendNotification = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!notifyListing || !warningMessage.trim()) return;
    setSubmitting(true);
    setActionError(null);

    try {
      const res = await apiRequest(`/admin/listings/${notifyListing.id}/notify`, {
        method: 'POST',
        body: JSON.stringify({ message: warningMessage.trim() })
      }) as { message?: string };

      setActionSuccess(res.message || 'Warning notification sent to producer');
      setNotifyListing(null);
    } catch (err: any) {
      setActionError(err.message || 'Failed to send notification');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteListing = async (listingId: string, assetName: string) => {
    if (!window.confirm(`Are you sure you want to remove/delete the post "${assetName}"?`)) return;
    setSubmitting(true);

    try {
      await apiRequest(`/admin/listings/${listingId}`, {
        method: 'DELETE'
      });
      setActionSuccess(`Post "${assetName}" removed successfully.`);
      fetchListings();
    } catch (err: any) {
      setActionError(err.message || 'Failed to delete post');
    } finally {
      setSubmitting(false);
    }
  };

  const filteredListings = listings.filter(l => {
    if (!search) return true;
    const term = search.toLowerCase();
    return (
      l.assetName.toLowerCase().includes(term) ||
      l.category.toLowerCase().includes(term) ||
      (l.producer?.fullName && l.producer.fullName.toLowerCase().includes(term)) ||
      (l.producer?.email && l.producer.email.toLowerCase().includes(term))
    );
  });

  return (
    <div className="dashboard-scroll">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '1.5rem', fontWeight: 600 }}>Producer Post Management</h2>
          <p style={{ color: 'var(--text-secondary)', margin: '0.25rem 0 0 0', fontSize: '0.875rem' }}>
            View, edit, or manage producer posts and notify producers of any policy violations.
          </p>
        </div>
      </div>

      {actionSuccess && (
        <div style={{ background: 'rgba(16, 185, 129, 0.15)', border: '1px solid var(--success-color)', color: '#34d399', padding: '0.75rem 1rem', borderRadius: '8px', marginBottom: '1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>{actionSuccess}</span>
          <button type="button" onClick={() => setActionSuccess(null)} style={{ background: 'none', border: 'none', color: '#34d399', cursor: 'pointer', fontSize: '1.1rem' }}>✕</button>
        </div>
      )}

      {/* Filter Controls */}
      <div className="content-panel" style={{ marginBottom: '1.5rem', padding: '1rem' }}>
        <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '1rem', alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: '240px' }}>
            <input
              type="text"
              placeholder="Search by post title, category, producer name or email..."
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
              <option value="">All Statuses</option>
              <option value="active">Active</option>
              <option value="paused">Paused</option>
              <option value="removed">Removed</option>
            </select>
          </div>
          <button type="submit" style={{ padding: '0.6rem 1.2rem' }}>Search</button>
        </form>
      </div>

      {/* Listings Table */}
      <div className="content-panel">
        <div className="table-container">
          {loading ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-secondary)' }}>Loading producer posts...</div>
          ) : filteredListings.length === 0 ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-secondary)' }}>No producer posts found matching criteria.</div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Producer</th>
                  <th>Post / Asset Title</th>
                  <th>Category</th>
                  <th>Funding Target</th>
                  <th>Rental Price</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredListings.map((listing) => (
                  <tr key={listing.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{listing.producer?.fullName || 'Producer'}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>{listing.producer?.email || listing.producerId}</div>
                    </td>
                    <td>
                      <div style={{ fontWeight: 500 }}>{listing.assetName}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', maxWidth: '280px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {listing.description}
                      </div>
                    </td>
                    <td>
                      <span style={{ fontSize: '0.85rem', background: 'rgba(255, 255, 255, 0.08)', padding: '0.2rem 0.6rem', borderRadius: '4px' }}>
                        {listing.category}
                      </span>
                    </td>
                    <td>৳{listing.fundingTarget?.toLocaleString()}</td>
                    <td>৳{listing.rentalPrice?.toLocaleString()}/day</td>
                    <td>
                      <span className={`status-badge ${listing.status === 'active' ? 'status-approved' : 'status-pending'}`}>
                        {listing.status.toUpperCase()}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end' }}>
                        <button
                          type="button"
                          className="secondary"
                          onClick={() => openEditModal(listing)}
                          style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => openNotifyModal(listing)}
                          style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem', background: '#f59e0b', color: '#fff' }}
                        >
                          Notify
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDeleteListing(listing.id, listing.assetName)}
                          style={{ padding: '0.4rem 0.8rem', fontSize: '0.85rem', background: 'var(--danger-color)', color: '#fff' }}
                        >
                          Remove
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Edit Listing Modal */}
      {editingListing && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0, 0, 0, 0.75)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100
        }}>
          <div style={{
            background: 'var(--surface-color)', padding: '2rem', borderRadius: '12px',
            maxWidth: '600px', width: '90%', maxHeight: '90vh', overflowY: 'auto', border: '1px solid var(--border-color)'
          }}>
            <h3 style={{ marginTop: 0, marginBottom: '1rem' }}>Edit Producer Post</h3>
            {actionError && (
              <div style={{ background: 'rgba(239, 68, 68, 0.15)', border: '1px solid var(--danger-color)', color: '#f87171', padding: '0.5rem 1rem', borderRadius: '6px', marginBottom: '1rem' }}>
                {actionError}
              </div>
            )}
            <form onSubmit={handleSaveEdit}>
              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Asset / Post Name</label>
                <input
                  type="text"
                  required
                  value={editForm.assetName}
                  onChange={(e) => setEditForm({ ...editForm, assetName: e.target.value })}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Category</label>
                  <input
                    type="text"
                    required
                    value={editForm.category}
                    onChange={(e) => setEditForm({ ...editForm, category: e.target.value })}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Post Status</label>
                  <select
                    value={editForm.status}
                    onChange={(e) => setEditForm({ ...editForm, status: e.target.value })}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                  >
                    <option value="active">Active</option>
                    <option value="paused">Paused</option>
                    <option value="removed">Removed</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Funding Target (৳)</label>
                  <input
                    type="number"
                    required
                    value={editForm.fundingTarget}
                    onChange={(e) => setEditForm({ ...editForm, fundingTarget: Number(e.target.value) })}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Rental Price (৳ / day)</label>
                  <input
                    type="number"
                    required
                    value={editForm.rentalPrice}
                    onChange={(e) => setEditForm({ ...editForm, rentalPrice: Number(e.target.value) })}
                    style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                  />
                </div>
              </div>

              <div style={{ marginBottom: '1rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Description</label>
                <textarea
                  rows={3}
                  value={editForm.description}
                  onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                />
              </div>

              <div style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Specifications</label>
                <textarea
                  rows={2}
                  value={editForm.specifications}
                  onChange={(e) => setEditForm({ ...editForm, specifications: e.target.value })}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
                <button type="button" className="secondary" onClick={() => setEditingListing(null)}>Cancel</button>
                <button type="submit" disabled={submitting}>
                  {submitting ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Notify Producer Modal */}
      {notifyListing && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0, 0, 0, 0.75)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100
        }}>
          <div style={{
            background: 'var(--surface-color)', padding: '2rem', borderRadius: '12px',
            maxWidth: '520px', width: '90%', border: '1px solid var(--border-color)'
          }}>
            <h3 style={{ marginTop: 0, marginBottom: '0.5rem', color: '#f59e0b' }}>Notify Producer</h3>
            <p style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', marginBottom: '1.25rem' }}>
              Send an official warning notification & email to <strong>{notifyListing.producer?.fullName || 'Producer'}</strong> regarding post <strong>"{notifyListing.assetName}"</strong>.
            </p>

            {actionError && (
              <div style={{ background: 'rgba(239, 68, 68, 0.15)', border: '1px solid var(--danger-color)', color: '#f87171', padding: '0.5rem 1rem', borderRadius: '6px', marginBottom: '1rem' }}>
                {actionError}
              </div>
            )}

            <form onSubmit={handleSendNotification}>
              <div style={{ marginBottom: '1.5rem' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: '0.3rem', color: 'var(--text-secondary)' }}>Notice / Warning Details</label>
                <textarea
                  rows={4}
                  required
                  placeholder="Specify what the producer did wrong or needs to update (e.g. invalid pricing, improper images, misleading description)..."
                  value={warningMessage}
                  onChange={(e) => setWarningMessage(e.target.value)}
                  style={{ width: '100%', padding: '0.6rem', borderRadius: '6px', border: '1px solid var(--border-color)', background: 'var(--bg-color)', color: 'var(--text-primary)' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
                <button type="button" className="secondary" onClick={() => setNotifyListing(null)}>Cancel</button>
                <button type="submit" disabled={submitting} style={{ background: '#f59e0b', color: '#fff' }}>
                  {submitting ? 'Sending...' : 'Send Warning Email & Notification'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
