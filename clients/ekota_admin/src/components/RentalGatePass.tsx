import { useEffect, useRef, useState } from 'react';
import { Html5Qrcode } from 'html5-qrcode';
import { apiRequest } from '../lib/api';

interface ScanRental {
  id: string;
  status: string;
  pickupAt?: string;
  returnedAt?: string;
  expectedReturnAt?: string;
  daysRented?: number;
  totalCost?: number;
  assetName: string;
  renterName: string;
  renterEmail: string;
}

interface ScanResult {
  success: boolean;
  action?: 'pickup' | 'return';
  message?: string;
  error?: string;
  rental?: ScanRental;
}

const STATUS_LABEL: Record<string, string> = {
  PENDING_PICKUP: 'Pending Pickup',
  ACTIVE: 'Active',
  RETURNED: 'Returned',
};

function formatDate(iso?: string): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

interface CameraDevice {
  id: string;
  label: string;
}

/** Map a getUserMedia / html5-qrcode error to a human-readable message. */
function describeCameraError(err: unknown): string {
  const name = err instanceof DOMException ? err.name : (err as { name?: string })?.name;
  const message = err instanceof Error ? err.message : String(err);

  switch (name) {
    case 'NotAllowedError':
    case 'PermissionDeniedError':
      return 'Camera permission was denied. Allow camera access in your browser (click the 🔒 icon in the address bar) and try again.';
    case 'NotFoundError':
    case 'DevicesNotFoundError':
      return 'No camera was detected on this device (this is not a permission issue — the browser found no camera hardware). Check that a camera is connected and enabled, then try again. You can use manual entry below.';
    case 'NotReadableError':
    case 'TrackStartError':
      return 'The camera is already in use by another app or tab. Close it and try again.';
    case 'OverconstrainedError':
      return 'The selected camera could not satisfy the requested settings. Try a different camera below.';
    case 'SecurityError':
      return 'Camera access requires a secure context. Open this app via https:// or http://localhost and try again.';
    default:
      return `Could not start the camera (${name || 'unknown error'}: ${message}). Check browser permissions or use manual entry below.`;
  }
}

export function RentalGatePass() {
  const [scanning, setScanning] = useState(false);
  const [enumerating, setEnumerating] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [cameras, setCameras] = useState<CameraDevice[]>([]);
  const [selectedCamera, setSelectedCamera] = useState<string>('');
  const [result, setResult] = useState<ScanResult | null>(null);
  const [manualCode, setManualCode] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [busy, setBusy] = useState(false);
  const scannerRef = useRef<Html5Qrcode | null>(null);
  const lastScanRef = useRef<number>(0);

  useEffect(() => {
    return () => {
      // Clean up the camera when the component unmounts.
      if (scannerRef.current) {
        scannerRef.current
          .stop()
          .then(() => scannerRef.current?.clear())
          .catch(() => undefined);
      }
    };
  }, []);

  const stopScanner = async () => {
    if (scannerRef.current) {
      try {
        await scannerRef.current.stop();
        scannerRef.current.clear();
      } catch {
        // Ignore — camera may already be stopped.
      }
      scannerRef.current = null;
    }
    setScanning(false);
  };

  const startScanner = async (cameraId?: string) => {
    setCameraError(null);
    setResult(null);
    setEnumerating(true);

    // Enumerate cameras first. Note: getCameras() itself calls getUserMedia,
    // so this is where the browser shows the permission prompt — and where a
    // NotFoundError surfaces if the machine has no camera at all.
    let devices: CameraDevice[];
    try {
      devices = await Html5Qrcode.getCameras();
    } catch (err) {
      setScanning(false);
      setCameraError(describeCameraError(err));
      console.error('QR scanner camera enumeration error:', err);
      return;
    } finally {
      setEnumerating(false);
    }

    if (!devices || devices.length === 0) {
      setScanning(false);
      setCameraError(
        'No camera was detected on this device (this is not a permission issue — the browser found no camera hardware). Check that a camera is connected and enabled, then try again. You can use manual entry below.',
      );
      return;
    }

    setCameras(devices);
    // Prefer a back/environment camera, otherwise fall back to the first one.
    const preferred =
      devices.find((d) => /back|environment|rear/i.test(d.label)) ?? devices[0];
    const deviceId = cameraId || selectedCamera || preferred.id;
    setSelectedCamera(deviceId);

    setScanning(true);
    const scanner = new Html5Qrcode('qr-reader');
    scannerRef.current = scanner;

    // Try the concrete device first, then fall back to facingMode, then to the
    // browser default. The final `{}` always triggers the permission prompt and
    // works with any camera, so scanning starts as long as one exists.
    const attempts: MediaTrackConstraints[] = [
      { deviceId: { exact: deviceId } },
      { facingMode: 'environment' },
      { facingMode: 'user' },
      {},
    ];

    let started = false;
    let lastErr: unknown = null;
    for (const constraints of attempts) {
      try {
        await scanner.start(
          constraints,
          { fps: 10, qrbox: { width: 250, height: 250 } },
          (decodedText) => {
            // Debounce: ignore duplicate frames from the same code.
            const now = Date.now();
            if (now - lastScanRef.current < 1500) return;
            lastScanRef.current = now;
            void handleCode(decodedText.trim());
          },
          () => {
            // Per-frame decode errors are expected while scanning — ignore.
          },
        );
        started = true;
        break;
      } catch (err) {
        lastErr = err;
        // Try the next constraint set.
      }
    }

    if (!started) {
      setScanning(false);
      setCameraError(describeCameraError(lastErr));
      console.error('QR scanner start error:', lastErr);
    }
  };

  const handleCameraChange = (deviceId: string) => {
    setSelectedCamera(deviceId);
    // Restart the scanner with the newly selected camera.
    void stopScanner().then(() => startScanner(deviceId));
  };

  const handleCode = async (code: string) => {
    if (!code || busy) return;
    setBusy(true);
    setResult(null);
    try {
      const payload = (await apiRequest('/rentals/gate-pass/scan', {
        method: 'POST',
        body: JSON.stringify({ code }),
      })) as ScanResult;
      setResult(payload);
      // A successful scan closes the loop — stop the camera.
      if (payload.success) {
        await stopScanner();
      }
    } catch (err) {
      setResult({
        success: false,
        error: err instanceof Error ? err.message : 'Scan request failed',
      });
    } finally {
      setBusy(false);
    }
  };

  const handleManualSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualCode.trim()) return;
    void handleCode(manualCode.trim());
  };

  const actionBadge = result?.action === 'pickup' ? 'PICKUP VERIFIED' : 'RETURN VERIFIED';

  return (
    <div className="gate-pass-page">
      <div className="content-panel">
        <h3>Warehouse Gate — Rental Verification</h3>
        <p className="gate-pass-subtitle">
          Scan the renter's digital gate-pass QR code to verify and log product pick-up or return.
          The system automatically detects whether the scan is a pickup or a return from the
          rental's current status.
        </p>

        <div className="gate-pass-grid">
          {/* Scanner panel */}
          <div className="gate-pass-card">
            <div className="gate-pass-card-header">
              <span className="gate-pass-card-title">📷 Scan Gate-Pass</span>
              {scanning && <span className="status-badge status-pending">Scanning…</span>}
            </div>

            <div id="qr-reader" className="qr-reader-box" />

            {cameraError && (
              <div className="gate-pass-error">
                <span>⚠️</span> {cameraError}
              </div>
            )}

            {cameras.length > 1 && (
              <div className="gate-pass-camera-select">
                <label htmlFor="camera-select">Camera</label>
                <select
                  id="camera-select"
                  value={selectedCamera}
                  onChange={(e) => handleCameraChange(e.target.value)}
                  disabled={scanning && !selectedCamera}
                >
                  {cameras.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.label || `Camera ${c.id.slice(0, 8)}`}
                    </option>
                  ))}
                </select>
              </div>
            )}

            <div className="gate-pass-actions">
              {!scanning ? (
                <button type="button" onClick={() => void startScanner()} disabled={enumerating}>
                  {enumerating ? 'Looking for camera…' : 'Start Camera Scan'}
                </button>
              ) : (
                <button type="button" className="secondary" onClick={() => void stopScanner()}>
                  Stop Camera
                </button>
              )}
            </div>

            {!scanning && !cameraError && (
              <p className="gate-pass-hint gate-pass-permission-hint">
                Your browser will ask for camera permission the first time you start a scan.
              </p>
            )}
          </div>

          {/* Manual entry panel */}
          <div className="gate-pass-card">
            <div className="gate-pass-card-header">
              <span className="gate-pass-card-title">⌨️ Manual Entry</span>
            </div>
            <p className="gate-pass-hint">
              If the camera is unavailable, type the gate-pass code shown under the renter's QR.
            </p>
            <form onSubmit={handleManualSubmit} className="gate-pass-form">
              <input
                type="text"
                value={manualCode}
                onChange={(e) => setManualCode(e.target.value)}
                placeholder="Paste gate-pass code…"
                className="gate-pass-input"
              />
              <button type="submit" disabled={submitting || busy || !manualCode.trim()}>
                {busy ? 'Verifying…' : 'Verify Gate-Pass'}
              </button>
            </form>
          </div>
        </div>

        {/* Result panel */}
        {result && (
          <div className={`gate-pass-result ${result.success ? 'success' : 'error'}`}>
            {result.success ? (
              <>
                <div className="gate-pass-result-header">
                  <span className="gate-pass-result-icon">✅</span>
                  <div>
                    <span className="gate-pass-result-title">{actionBadge}</span>
                    <p className="gate-pass-result-message">{result.message}</p>
                  </div>
                </div>
                {result.rental && (
                  <div className="gate-pass-rental-details">
                    <div className="detail-row">
                      <span>Product</span>
                      <strong>{result.rental.assetName}</strong>
                    </div>
                    <div className="detail-row">
                      <span>Renter</span>
                      <strong>
                        {result.rental.renterName}
                        <span className="detail-sub">{result.rental.renterEmail}</span>
                      </strong>
                    </div>
                    <div className="detail-row">
                      <span>Status</span>
                      <strong>{STATUS_LABEL[result.rental.status] ?? result.rental.status}</strong>
                    </div>
                    {result.rental.pickupAt && (
                      <div className="detail-row">
                        <span>Picked up</span>
                        <strong>{formatDate(result.rental.pickupAt)}</strong>
                      </div>
                    )}
                    {result.rental.returnedAt && (
                      <div className="detail-row">
                        <span>Returned</span>
                        <strong>{formatDate(result.rental.returnedAt)}</strong>
                      </div>
                    )}
                    {result.rental.expectedReturnAt && (
                      <div className="detail-row">
                        <span>Expected return</span>
                        <strong>{formatDate(result.rental.expectedReturnAt)}</strong>
                      </div>
                    )}
                    {result.rental.daysRented != null && (
                      <div className="detail-row">
                        <span>Days rented</span>
                        <strong>{result.rental.daysRented}</strong>
                      </div>
                    )}
                    {result.rental.totalCost != null && (
                      <div className="detail-row">
                        <span>Total cost</span>
                        <strong>৳{result.rental.totalCost.toLocaleString()}</strong>
                      </div>
                    )}
                  </div>
                )}
              </>
            ) : (
              <div className="gate-pass-result-header">
                <span className="gate-pass-result-icon">❌</span>
                <div>
                  <span className="gate-pass-result-title">Verification Failed</span>
                  <p className="gate-pass-result-message">{result.error ?? 'Unknown error'}</p>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}