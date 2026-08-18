/* End-to-end test of the Active Rental Portal + Warehouse Gate-Pass flow.
 * Run with: node e2e_rental_portal_test.js
 */
const BASE = 'http://localhost:5000/api';

async function api(path, { method = 'GET', token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}

async function login(email) {
  const { status, data } = await api('/auth/login', {
    method: 'POST',
    body: { email, password: 'Password123!' },
  });
  if (status !== 200 && status !== 201) {
    throw new Error(`Login failed for ${email}: ${status} ${JSON.stringify(data)}`);
  }
  return data.token || data.accessToken || data.data?.token;
}

function assert(cond, msg) {
  if (!cond) throw new Error(`ASSERT FAILED: ${msg}`);
  console.log(`  ✓ ${msg}`);
}

async function main() {
  console.log('== Login ==');
  const renterToken = await login('renter1@ekota.test');
  const adminToken = await login('admin1@ekota.test');
  console.log('  ✓ renter + admin logged in');

  console.log('\n== Rental pool ==');
  const pool = await api('/rental-pool', { token: renterToken });
  assert(pool.status === 200, `GET /rental-pool -> ${pool.status}`);
  const available = (pool.data || []).filter((i) => i.status === 'AVAILABLE');
  assert(available.length > 0, `at least one AVAILABLE pool item (found ${available.length})`);
  const item = available[0];
  console.log(`  using pool item: ${item.assetName} (${item.id})`);

  console.log('\n== Rent product (booking confirmed) ==');
  const rent = await api(`/rental-pool/${item.id}/rent`, {
    method: 'POST',
    token: renterToken,
    body: { durationDays: 3 },
  });
  assert(rent.status === 201, `POST rent -> ${rent.status}`);
  const rental = rent.data.rental;
  assert(rental.status === 'PENDING_PICKUP', `rental status is PENDING_PICKUP (got ${rental.status})`);
  assert(!!rental.gatePassCode, 'gate-pass code generated');
  assert(!!rental.expectedReturnAt, 'expected return deadline set');
  console.log(`  rental id: ${rental.id}`);
  console.log(`  gate-pass code: ${rental.gatePassCode}`);
  console.log(`  expected return: ${rental.expectedReturnAt}`);

  console.log('\n== Renter portal ==');
  const portal = await api(`/rentals/${rental.id}/portal`, { token: renterToken });
  assert(portal.status === 200, `GET portal -> ${portal.status}`);
  assert(portal.data.gatePassCode === rental.gatePassCode, 'portal exposes gate-pass code');
  assert(portal.data.events.some((e) => e.type === 'CREATED'), 'portal has CREATED event');
  console.log(`  portal status: ${portal.data.status}`);

  console.log('\n== Warehouse scan #1: pickup ==');
  const scan1 = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: rental.gatePassCode },
  });
  assert(scan1.status === 200, `scan pickup -> ${scan1.status}`);
  assert(scan1.data.success === true, 'scan success');
  assert(scan1.data.action === 'pickup', `action is pickup (got ${scan1.data.action})`);
  assert(scan1.data.rental.status === 'ACTIVE', `status now ACTIVE (got ${scan1.data.rental.status})`);
  console.log(`  ${scan1.data.message}`);

  console.log('\n== Portal after pickup ==');
  const portal2 = await api(`/rentals/${rental.id}/portal`, { token: renterToken });
  assert(portal2.data.status === 'ACTIVE', 'portal reflects ACTIVE');
  assert(portal2.data.pickupAt != null, 'pickupAt recorded');
  assert(portal2.data.pickupVerifiedBy?.fullName, 'pickup verifier recorded');
  assert(portal2.data.events.some((e) => e.type === 'PICKED_UP'), 'PICKED_UP event logged');
  console.log(`  verified by: ${portal2.data.pickupVerifiedBy.fullName}`);

  console.log('\n== Renter requests return (new return gate-pass) ==');
  const reqReturn = await api(`/rental-pool/${item.id}/return`, {
    method: 'POST',
    token: renterToken,
  });
  assert(reqReturn.status === 200, `POST return request -> ${reqReturn.status}`);
  const returnCode = reqReturn.data.returnGatePassCode;
  assert(!!returnCode, 'new return gate-pass code generated');
  assert(reqReturn.data.rental.status === 'ACTIVE', `rental still ACTIVE after request (got ${reqReturn.data.rental.status})`);
  console.log(`  return gate-pass code: ${returnCode}`);

  console.log('\n== Portal shows return gate-pass ==');
  const portal3 = await api(`/rentals/${rental.id}/portal`, { token: renterToken });
  assert(portal3.data.returnGatePassCode === returnCode, 'portal exposes return gate-pass code');
  assert(portal3.data.status === 'ACTIVE', 'portal still ACTIVE');

  console.log('\n== Pickup QR can no longer be used to return ==');
  const scanPickupAgain = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: rental.gatePassCode },
  });
  assert(scanPickupAgain.status === 400, `pickup QR rejected for return -> ${scanPickupAgain.status}`);

  console.log('\n== Warehouse scan #2: return (return gate-pass) ==');
  const scan2 = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: returnCode },
  });
  assert(scan2.status === 200, `scan return -> ${scan2.status}`);
  assert(scan2.data.action === 'return', `action is return (got ${scan2.data.action})`);
  assert(scan2.data.rental.status === 'RETURNED', `status now RETURNED (got ${scan2.data.rental.status})`);
  assert(scan2.data.rental.totalCost != null, 'total cost computed');
  console.log(`  ${scan2.data.message} (total ৳${scan2.data.rental.totalCost})`);

  console.log('\n== Pool item freed ==');
  const poolAfter = await api('/rental-pool', { token: renterToken });
  const freed = (poolAfter.data || []).find((i) => i.id === item.id);
  assert(freed && freed.status === 'AVAILABLE', 'pool item back to AVAILABLE');

  console.log('\n== Scan of already-returned rental ==');
  const scan3 = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: returnCode },
  });
  assert(scan3.status === 400, `re-scan rejected -> ${scan3.status}`);

  console.log('\n== Invalid gate-pass ==');
  const bad = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: 'not-a-real-code' },
  });
  assert(bad.status === 404, `invalid code -> ${bad.status}`);

  console.log('\n== App return flow (request + warehouse verify) ==');
  const pool2 = await api('/rental-pool', { token: renterToken });
  const avail2 = (pool2.data || []).filter((i) => i.status === 'AVAILABLE');
  assert(avail2.length > 0, `at least one AVAILABLE item for app-return test (found ${avail2.length})`);
  const item2 = avail2[0];
  const rent2 = await api(`/rental-pool/${item2.id}/rent`, {
    method: 'POST',
    token: renterToken,
    body: { durationDays: 2 },
  });
  assert(rent2.status === 201, `rent item2 -> ${rent2.status}`);
  const code2 = rent2.data.rental.gatePassCode;

  // Pick up item2 first so it can be returned.
  const pickup2 = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: code2 },
  });
  assert(pickup2.status === 200 && pickup2.data.action === 'pickup', 'item2 picked up');

  // Request return -> generates a NEW return gate-pass.
  const reqReturn2 = await api(`/rental-pool/${item2.id}/return`, { method: 'POST', token: renterToken });
  assert(reqReturn2.status === 200, `return request -> ${reqReturn2.status}`);
  const returnCode2 = reqReturn2.data.returnGatePassCode;
  assert(!!returnCode2, 'item2 return gate-pass generated');
  assert(reqReturn2.data.rental.status === 'ACTIVE', 'item2 still ACTIVE after request');

  // Wrong return code -> no matching rental.
  const wrongScan = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: 'wrong-code' },
  });
  assert(wrongScan.status === 404, `scan with wrong code -> ${wrongScan.status}`);

  // Correct return code -> return completed.
  const okReturn = await api('/rentals/gate-pass/scan', {
    method: 'POST',
    token: adminToken,
    body: { code: returnCode2 },
  });
  assert(okReturn.status === 200, `scan return code -> ${okReturn.status}`);
  assert(okReturn.data.rental.status === 'RETURNED', `item2 status RETURNED (got ${okReturn.data.rental.status})`);
  assert(okReturn.data.rental.totalCost != null, 'item2 total cost computed');

  const poolAfter2 = await api('/rental-pool', { token: renterToken });
  const freed2 = (poolAfter2.data || []).find((i) => i.id === item2.id);
  assert(freed2 && freed2.status === 'AVAILABLE', 'item2 pool item back to AVAILABLE');

  console.log('\n✅ ALL TESTS PASSED');
}

main().catch((err) => {
  console.error('\n❌ TEST FAILED:', err.message);
  process.exit(1);
});