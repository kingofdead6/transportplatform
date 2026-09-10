/* eslint-disable no-console */
// End-to-end smoke test of the real API against an in-memory MongoDB.
// Run with: npm run test:e2e
process.env.JWT_SECRET = 'test-secret';
process.env.NODE_ENV = 'test';
process.env.CLOUDINARY_CLOUD_NAME = 'test';

const assert = require('assert');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const request = require('supertest');

const app = require('../src/app');
const User = require('../src/models/User');

let passed = 0;
let failed = 0;

async function check(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed += 1;
    console.log(`  FAIL  ${name}\n        ${err.message}`);
  }
}

async function main() {
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());

  const api = request(app);
  const auth = (t) => ({ Authorization: `Bearer ${t}` });

  // ---- accounts -------------------------------------------------------
  const reg = async (phone, role, extra = {}) => {
    const res = await api.post('/api/auth/register').send({ phone, password: 'secret123', role, ...extra });
    return res.body;
  };

  const shipper = await reg('+213700000001', 'shipper', { companyName: 'Shipper SARL' });
  const carrier = await reg('+213700000002', 'carrier', { companyName: 'Carrier SPA' });
  const carrier2 = await reg('+213700000003', 'carrier', { companyName: 'Rival SPA' });

  // Approve shipper + carriers (they register as 'pending').
  await User.updateMany(
    { _id: { $in: [shipper.user._id, carrier.user._id, carrier2.user._id] } },
    { status: 'active' }
  );

  const admin = await User.create({
    phone: '+213700000009',
    password: 'secret123',
    role: 'admin',
    adminSubRole: 'direction',
    status: 'active',
  });
  const adminLogin = await api.post('/api/auth/login').send({ phone: admin.phone, password: 'secret123' });
  const adminToken = adminLogin.body.token;

  const sT = shipper.token;
  const cT = carrier.token;
  const c2T = carrier2.token;

  console.log('\n== Auth & accounts ==');

  await check('blocked account gets 403 (not a mislabelled 401)', async () => {
    const blocked = await reg('+213700000010', 'shipper');
    await User.updateOne({ _id: blocked.user._id }, { status: 'blocked' });
    const res = await api.get('/api/auth/me').set(auth(blocked.token));
    assert.strictEqual(res.status, 403, `expected 403, got ${res.status}`);
    assert.match(res.body.message, /blocked/i);
  });

  await check('duplicate phone registration returns 409', async () => {
    const res = await api
      .post('/api/auth/register')
      .send({ phone: '+213700000001', password: 'secret123', role: 'shipper' });
    assert.strictEqual(res.status, 409);
  });

  console.log('\n== Driver creation & login (was impossible before) ==');

  let driverId;
  await check('carrier cannot create a driver without a password', async () => {
    const res = await api
      .post('/api/users/drivers')
      .set(auth(cT))
      .send({ phone: '+213700000004', fullName: 'Ali' });
    assert.strictEqual(res.status, 400);
  });

  await check('carrier creates a driver with a password', async () => {
    const res = await api
      .post('/api/users/drivers')
      .set(auth(cT))
      .send({ phone: '+213700000004', fullName: 'Ali', password: 'drive123' });
    assert.strictEqual(res.status, 201, JSON.stringify(res.body));
    driverId = res.body._id;
  });

  let dT;
  await check('that driver can actually log in', async () => {
    const res = await api.post('/api/auth/login').send({ phone: '+213700000004', password: 'drive123' });
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
    dT = res.body.token;
  });

  await check('duplicate driver phone returns 409, not a 500', async () => {
    const res = await api
      .post('/api/users/drivers')
      .set(auth(cT))
      .send({ phone: '+213700000004', fullName: 'Dup', password: 'drive123' });
    assert.strictEqual(res.status, 409);
  });

  console.log('\n== Fixed-price load: create -> publish -> accept ==');

  let fixedTripId;
  await check('shipper creates a fixed-price trip', async () => {
    const res = await api
      .post('/api/trips')
      .set(auth(sT))
      .send({
        pickup: { wilaya: 'Alger', address: 'Port', lat: 36.75, lng: 3.06 },
        dropoff: { wilaya: 'Oran', address: 'Zone', lat: 35.69, lng: -0.63 },
        goodsType: 'palletized',
        vehicleTypeRequired: 'flatbed',
        pricingMode: 'fixed',
        fixedPrice: 50000,
        weightKg: 12000,
      });
    assert.strictEqual(res.status, 201, JSON.stringify(res.body));
    fixedTripId = res.body._id;
    assert.match(res.body.reference, /^PP-\d{4}-\d{6}$/);
  });

  await check('fixed-price trip without a price is rejected', async () => {
    const res = await api.post('/api/trips').set(auth(sT)).send({
      goodsType: 'bulk',
      vehicleTypeRequired: 'tipper',
      pricingMode: 'fixed',
    });
    assert.strictEqual(res.status, 400);
  });

  await check('shipper publishes it', async () => {
    const res = await api.put(`/api/trips/${fixedTripId}/publish`).set(auth(sT));
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'published');
  });

  await check('carrier sees it on the marketplace', async () => {
    const res = await api.get('/api/trips').set(auth(cT));
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.some((t) => t._id === fixedTripId), 'trip missing from marketplace');
  });

  await check('carrier ACCEPTS the fixed-price load (previously impossible)', async () => {
    const res = await api.put(`/api/trips/${fixedTripId}/accept`).set(auth(cT));
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
    assert.strictEqual(res.body.status, 'assigned');
    assert.strictEqual(res.body.agreedPrice, 50000);
    assert.strictEqual(res.body.commission.computedAmount, 5000); // 10% default
  });

  await check('a second carrier cannot take the same load', async () => {
    const res = await api.put(`/api/trips/${fixedTripId}/accept`).set(auth(c2T));
    assert.strictEqual(res.status, 409, `expected 409, got ${res.status}`);
  });

  await check('rival carrier can no longer view the taken trip', async () => {
    const res = await api.get(`/api/trips/${fixedTripId}`).set(auth(c2T));
    assert.strictEqual(res.status, 403);
  });

  console.log('\n== Driver assignment & tenancy ==');

  await check('carrier cannot assign a rival carrier\'s driver', async () => {
    const rivalDriver = await User.create({
      phone: '+213700000055',
      role: 'driver',
      carrierId: carrier2.user._id,
      status: 'active',
    });
    const res = await api
      .put(`/api/trips/${fixedTripId}/assign-driver`)
      .set(auth(cT))
      .send({ driverId: rivalDriver._id });
    assert.strictEqual(res.status, 403, `expected 403, got ${res.status}`);
  });

  await check('carrier assigns their own driver', async () => {
    const res = await api
      .put(`/api/trips/${fixedTripId}/assign-driver`)
      .set(auth(cT))
      .send({ driverId });
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
    assert.strictEqual(res.body.status, 'driver_assigned');
  });

  console.log('\n== Driver mission flow ==');

  await check('driver advances through the lifecycle', async () => {
    for (const status of ['en_route_pickup', 'loaded', 'en_route_delivery', 'arrived_delivery', 'delivered']) {
      const res = await api
        .put(`/api/trips/${fixedTripId}/status`)
        .set(auth(dT))
        .send({ status, lat: 36.5, lng: 2.9 });
      assert.strictEqual(res.status, 200, `${status}: ${JSON.stringify(res.body)}`);
      assert.strictEqual(res.body.status, status);
    }
  });

  await check('illegal transition is rejected', async () => {
    const res = await api.put(`/api/trips/${fixedTripId}/status`).set(auth(dT)).send({ status: 'loaded' });
    assert.strictEqual(res.status, 400);
  });

  await check('an unrelated driver cannot ping this trip', async () => {
    const other = await reg('+213700000077', 'driver');
    const res = await api
      .post(`/api/trips/${fixedTripId}/ping`)
      .set(auth(other.token))
      .send({ lat: 1, lng: 1 });
    assert.strictEqual(res.status, 403, `expected 403, got ${res.status}`);
  });

  await check('the assigned driver can ping', async () => {
    const res = await api.post(`/api/trips/${fixedTripId}/ping`).set(auth(dT)).send({ lat: 36, lng: 3 });
    assert.strictEqual(res.status, 200);
  });

  console.log('\n== POD, review, invoicing ==');

  await check('shipper confirms receipt', async () => {
    const res = await api.put(`/api/trips/${fixedTripId}/confirm-pod`).set(auth(sT));
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'pod_confirmed');
  });

  await check('shipper reviews the carrier', async () => {
    const res = await api
      .post(`/api/trips/${fixedTripId}/review`)
      .set(auth(sT))
      .send({ rating: 5, punctuality: 5, goodsCondition: 5, behavior: 5, comment: 'Bien' });
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
  });

  await check('a second review is rejected (rating inflation)', async () => {
    const res = await api.post(`/api/trips/${fixedTripId}/review`).set(auth(sT)).send({ rating: 5 });
    assert.strictEqual(res.status, 409);
  });

  await check('out-of-range rating is rejected', async () => {
    const t2 = await api.post('/api/trips').set(auth(sT)).send({
      pickup: { wilaya: 'Alger' },
      dropoff: { wilaya: 'Blida' },
      goodsType: 'bulk',
      vehicleTypeRequired: 'tipper',
      pricingMode: 'fixed',
      fixedPrice: 100,
    });
    const res = await api.post(`/api/trips/${t2.body._id}/review`).set(auth(sT)).send({ rating: 99 });
    assert.ok(res.status === 400, `expected 400, got ${res.status}`);
  });

  let invoiceId;
  await check('admin issues the invoice with correct VAT', async () => {
    const res = await api.post(`/api/trips/${fixedTripId}/invoice`).set(auth(adminToken)).send({});
    assert.strictEqual(res.status, 201, JSON.stringify(res.body));
    invoiceId = res.body._id;
    assert.strictEqual(res.body.agreedAmount, 50000);
    assert.strictEqual(res.body.vatAmount, 9500); // 19%
    assert.strictEqual(res.body.totalAmount, 59500);
    assert.strictEqual(res.body.balanceDue, 59500);
  });

  await check('double invoicing is rejected', async () => {
    const res = await api.post(`/api/trips/${fixedTripId}/invoice`).set(auth(adminToken)).send({});
    assert.strictEqual(res.status, 409);
  });

  await check('overpayment is rejected', async () => {
    const res = await api
      .put(`/api/invoices/${invoiceId}/pay`)
      .set(auth(adminToken))
      .send({ amount: 999999, method: 'cash' });
    assert.strictEqual(res.status, 400);
  });

  await check('negative payment is rejected', async () => {
    const res = await api
      .put(`/api/invoices/${invoiceId}/pay`)
      .set(auth(adminToken))
      .send({ amount: -500, method: 'cash' });
    assert.strictEqual(res.status, 400);
  });

  await check('partial then full payment closes the invoice', async () => {
    let res = await api
      .put(`/api/invoices/${invoiceId}/pay`)
      .set(auth(adminToken))
      .send({ amount: 30000, method: 'cash' });
    assert.strictEqual(res.body.status, 'partially_paid');
    res = await api
      .put(`/api/invoices/${invoiceId}/pay`)
      .set(auth(adminToken))
      .send({ amount: 29500, method: 'cash' });
    assert.strictEqual(res.body.status, 'paid');
    assert.strictEqual(res.body.balanceDue, 0);
  });

  console.log('\n== Bidding flow ==');

  let bidTripId;
  await check('shipper publishes a bidding trip', async () => {
    const created = await api.post('/api/trips').set(auth(sT)).send({
      pickup: { wilaya: 'Alger' },
      dropoff: { wilaya: 'Setif' },
      goodsType: 'construction',
      vehicleTypeRequired: 'tipper',
      pricingMode: 'bidding',
    });
    bidTripId = created.body._id;
    const res = await api.put(`/api/trips/${bidTripId}/publish`).set(auth(sT));
    assert.strictEqual(res.status, 200);
  });

  await check('carrier cannot accept a bidding trip as fixed price', async () => {
    const res = await api.put(`/api/trips/${bidTripId}/accept`).set(auth(cT));
    assert.strictEqual(res.status, 400);
  });

  let offerId;
  await check('two carriers bid', async () => {
    const r1 = await api.post(`/api/trips/${bidTripId}/offers`).set(auth(cT)).send({ price: 40000 });
    assert.strictEqual(r1.status, 201, JSON.stringify(r1.body));
    const r2 = await api.post(`/api/trips/${bidTripId}/offers`).set(auth(c2T)).send({ price: 38000 });
    assert.strictEqual(r2.status, 201);
  });

  await check('duplicate pending bid is rejected', async () => {
    const res = await api.post(`/api/trips/${bidTripId}/offers`).set(auth(cT)).send({ price: 39000 });
    assert.strictEqual(res.status, 409);
  });

  await check('carrier sees only their OWN offer', async () => {
    const res = await api.get(`/api/trips/${bidTripId}`).set(auth(cT));
    assert.strictEqual(res.body.offers.length, 1, `saw ${res.body.offers.length} offers`);
    assert.strictEqual(res.body.offers[0].price, 40000);
  });

  await check('shipper sees all offers', async () => {
    const res = await api.get(`/api/trips/${bidTripId}`).set(auth(sT));
    assert.strictEqual(res.body.offers.length, 2);
    offerId = res.body.offers.find((o) => o.price === 38000)._id;
  });

  await check('shipper accepts the winning offer', async () => {
    const res = await api.put(`/api/trips/${bidTripId}/assign`).set(auth(sT)).send({ offerId });
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
    assert.strictEqual(res.body.status, 'assigned');
    assert.strictEqual(res.body.agreedPrice, 38000);
    const accepted = res.body.offers.filter((o) => o.status === 'accepted');
    const rejected = res.body.offers.filter((o) => o.status === 'rejected');
    assert.strictEqual(accepted.length, 1);
    assert.strictEqual(rejected.length, 1);
  });

  console.log('\n== Isolation & settings ==');

  await check('a shipper cannot read another shipper\'s trip', async () => {
    const other = await reg('+213700000088', 'shipper');
    await User.updateOne({ _id: other.user._id }, { status: 'active' });
    const res = await api.get(`/api/trips/${bidTripId}`).set(auth(other.token));
    assert.strictEqual(res.status, 403);
  });

  await check('carrier list is scoped to their own assigned trips with mine=true', async () => {
    const res = await api.get('/api/trips?mine=true').set(auth(cT));
    assert.ok(res.body.every((t) => String(t.assignedCarrierId?._id ?? t.assignedCarrierId) === String(carrier.user._id)));
  });

  await check('settings cannot be mass-assigned (lastInvoiceSeq protected)', async () => {
    const before = await api.get('/api/settings').set(auth(adminToken));
    const res = await api
      .put('/api/settings')
      .set(auth(adminToken))
      .send({ key: 'hacked', lastInvoiceSeq: 999999, defaultCommissionPercent: 12 });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.key, 'global');
    assert.strictEqual(res.body.defaultCommissionPercent, 12);
    assert.strictEqual(res.body.lastInvoiceSeq, before.body.lastInvoiceSeq);
  });

  await check('invalid commission percent is rejected', async () => {
    const res = await api.put('/api/settings').set(auth(adminToken)).send({ defaultCommissionPercent: 500 });
    assert.strictEqual(res.status, 400);
  });

  await check('non-admin cannot change settings', async () => {
    const res = await api.put('/api/settings').set(auth(sT)).send({ vatPercent: 0 });
    assert.strictEqual(res.status, 403);
  });

  await check('bad ObjectId returns 400, not a 500', async () => {
    const res = await api.get('/api/trips/not-a-real-id').set(auth(sT));
    assert.strictEqual(res.status, 400, `expected 400, got ${res.status}`);
  });

  await check('admin carrier lookup returns carriers by name', async () => {
    const res = await api.get('/api/users/carriers').set(auth(adminToken));
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.length >= 2);
    assert.ok(res.body[0].companyName, 'carrier lookup must expose companyName');
  });

  await check('password change works and old password stops working', async () => {
    const res = await api
      .put('/api/users/me/password')
      .set(auth(dT))
      .send({ currentPassword: 'drive123', newPassword: 'newpass123' });
    assert.strictEqual(res.status, 200, JSON.stringify(res.body));
    const old = await api.post('/api/auth/login').send({ phone: '+213700000004', password: 'drive123' });
    assert.strictEqual(old.status, 401);
    const now = await api.post('/api/auth/login').send({ phone: '+213700000004', password: 'newpass123' });
    assert.strictEqual(now.status, 200);
  });

  console.log(`\n${'='.repeat(50)}\n  ${passed} passed, ${failed} failed\n${'='.repeat(50)}`);

  await mongoose.disconnect();
  await mongo.stop();
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('FATAL', err);
  process.exit(1);
});
