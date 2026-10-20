'use strict';
const { before, beforeEach, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const projectId = 'demo-smart-rice-auth';
if (process.env.GCLOUD_PROJECT !== projectId ||
    process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8089' ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098') {
  throw new Error('Inventory tests require explicit local Firestore/Auth emulators and demo project.');
}
const app = initializeApp({ projectId });
const db = getFirestore(app);
const now = Timestamp.now();
const iso = now.toDate().toISOString();
const expiry = Timestamp.fromMillis(now.toMillis() + 60 * 86400000);
let token;
async function call(name, data, authenticated = true) {
  const response = await fetch(`http://127.0.0.1:5002/${projectId}/us-central1/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json',
      ...(authenticated ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  return response.json();
}
function lot(code = 'LOT-1', quantity = 100) {
  return { code, riceId: 'rice', riceName: 'Rice', supplierId: 'supplier',
    supplierName: 'Supplier', quantity, remainingQuantity: quantity,
    status: 'available', importDate: now, manufactureDate: now, expiryDate: expiry };
}
function exportData(overrides = {}) {
  return { receipt: { id: 'exp', code: 'PX001', customerId: 'customer',
    customerName: 'FORGED', date: iso, riceId: 'rice', riceName: 'FORGED',
    quantity: 30, sellingPrice: 2, totalAmount: 60, note: '',
    allocations: [ { batchId: 'b1', allocatedQuantity: 10 }, { batchId: 'b2', allocatedQuantity: 20 } ],
    ...overrides } };
}
function importData(overrides = {}) {
  return { receipt: { id: 'imp', code: 'PN001', supplierId: 'supplier', date: iso,
    riceId: 'rice', quantity: 10, purchasePrice: 2, totalAmount: 20,
    batchCode: 'NEW', manufactureDate: iso, expiryDate: expiry.toDate().toISOString(), ...overrides },
    batch: { id: 'new', code: 'NEW', riceId: 'rice', supplierId: 'supplier', quantity: 10,
      manufactureDate: iso, expiryDate: expiry.toDate().toISOString() } };
}
function checkData(overrides = {}) {
  return { session: { id: 'check', code: 'KK001', createdBy: 'forged', items: [
    { batchId: 'b1', expectedQuantity: 100, actualQuantity: 90, difference: 999, reason: 'haoHut' },
    { batchId: 'b2', expectedQuantity: 100, actualQuantity: 110, difference: 999, reason: 'saiDuLieu' },
  ], ...overrides } };
}
before(async () => {
  await getAuth().createUser({ uid: 'staff', email: 'staff@example.com', password: 'local-password' });
  const response = await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'staff@example.com', password: 'local-password', returnSecureToken: true }),
  });
  token = (await response.json()).idToken;
  assert.ok(token, 'Auth emulator must return an ID token');
});
beforeEach(async () => {
  const reset = await fetch(`http://127.0.0.1:8089/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
  assert.equal(reset.ok, true);
  const batch = db.batch();
  batch.set(db.doc('users/staff'), { role: 'staff', isActive: true });
  for (const path of ['rice_products/rice', 'customers/customer', 'suppliers/supplier']) {
    batch.set(db.doc(path), { name: path.split('/')[0], isActive: true });
  }
  batch.set(db.doc('batches/b1'), lot());
  batch.set(db.doc('batches/b2'), lot('LOT-2'));
  await batch.commit();
});
after(async () => { await deleteApp(app); });

test('unauthenticated callable is denied', async () => {
  assert.equal((await call('confirmExport', exportData(), false)).error.status, 'UNAUTHENTICATED');
});
test('blocked and pending profiles cannot perform transactions', async () => {
  await db.doc('users/staff').update({ isActive: false });
  assert.equal((await call('confirmExport', exportData())).error.status, 'PERMISSION_DENIED');
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 100);
});
test('invalid role cannot perform transactions', async () => {
  await db.doc('users/staff').update({ role: 'admin\n' });
  assert.equal((await call('confirmExport', exportData())).error.status, 'PERMISSION_DENIED');
});
test('missing documents and malformed or negative quantities are rejected', async () => {
  for (const data of [{}, exportData({ quantity: -1 }), exportData({ quantity: '30' }), exportData({ quantity: null }),
    exportData({ allocations: [] }), exportData({ totalAmount: -1 }), exportData({ totalAmount: 1 }),
    exportData({ date: '2026-10-20T00:00:00.000' })]) {
    assert.ok((await call('confirmExport', data)).error);
  }
  assert.equal((await db.collection('export_receipts').get()).size, 0);
});
test('multi-lot export commits atomic stock and server-owned actor', async () => {
  const payload = exportData({ performedBy: 'admin' });
  payload.performedBy = 'admin';
  assert.equal((await call('confirmExport', payload)).result.success, true);
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 90);
  assert.equal((await db.doc('batches/b2').get()).data().quantity, 80);
  const receipt = (await db.doc('export_receipts/exp').get()).data();
  assert.equal(receipt.performedBy, 'staff');
  assert.equal(receipt.customerName, 'customers');
  const movements = await db.collection('stock_movements').get();
  assert.equal(movements.size, 2);
  for (const doc of movements.docs) {
    const m = doc.data();
    assert.equal(m.performedBy, 'staff');
    assert.equal(m.quantityBefore + m.quantityDelta, m.quantityAfter);
    assert.equal(m.referenceId, 'exp');
  }
});
test('missing, held, expired or insufficient second lot rejects all writes', async () => {
  for (const change of [{ status: 'qualityHold' }, { status: 'expired' }, { quantity: 1, remainingQuantity: 1 }]) {
    await db.doc('batches/b2').set({ ...lot('LOT-2'), ...change });
    assert.ok((await call('confirmExport', exportData())).error);
    assert.equal((await db.doc('batches/b1').get()).data().quantity, 100);
    assert.equal((await db.collection('export_receipts').get()).size, 0);
    assert.equal((await db.collection('stock_movements').get()).size, 0);
  }
  await db.doc('batches/b2').delete();
  assert.ok((await call('confirmExport', exportData())).error);
});
test('wrong rice and allocations mismatching the receipt are rejected', async () => {
  assert.ok((await call('confirmExport', exportData({ riceId: 'other' }))).error);
  assert.ok((await call('confirmExport', exportData({ quantity: 31, totalAmount: 62 }))).error);
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 100);
});
test('concurrent duplicate confirmations apply stock only once', async () => {
  const results = await Promise.all([call('confirmExport', exportData()), call('confirmExport', exportData())]);
  assert.equal(results.filter((r) => r.result?.success).length, 1);
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 90);
  assert.equal((await db.collection('stock_movements').get()).size, 2);
});
test('import creates a lot, receipt, reservation and ledger together', async () => {
  assert.equal((await call('confirmImport', importData())).result?.success, true);
  assert.equal((await db.doc('batches/new').get()).data().quantity, 10);
  assert.equal((await db.collection('batch_codes').get()).size, 1);
  assert.equal((await db.doc('import_receipts/imp').get()).data().performedBy, 'staff');
  assert.equal((await db.collection('stock_movements').get()).size, 1);
  assert.equal((await call('confirmImport', importData())).error.status, 'ALREADY_EXISTS');
});
test('supplement import uses the existing lot and preserves a hold', async () => {
  await db.doc('batches/b1').update({ status: 'qualityHold' });
  const data = importData({ batchCode: 'LOT-1' });
  data.batch.code = 'LOT-1';
  assert.equal((await call('confirmImport', data)).result?.success, true);
  const batch = (await db.doc('batches/b1').get()).data();
  assert.equal(batch.quantity, 110);
  assert.equal(batch.status, 'qualityHold');
  assert.equal((await db.doc('batches/new').get()).exists, false);
});
test('two clients cannot reserve different lots for one normalized code', async () => {
  const first = importData();
  const second = importData({ id: 'imp2', expiryDate: Timestamp.fromMillis(expiry.toMillis() + 86400000).toDate().toISOString() });
  second.batch = { ...first.batch, id: 'new2', expiryDate: second.receipt.expiryDate };
  const results = await Promise.all([call('confirmImport', first), call('confirmImport', second)]);
  assert.equal(results.filter((r) => r.result?.success).length, 1);
  assert.equal((await db.collection('import_receipts').get()).size, 1);
});
test('import rejects missing/mismatched batch and never overwrites an unrelated ID', async () => {
  assert.ok((await call('confirmImport', { receipt: importData().receipt })).error);
  const mismatch = importData(); mismatch.batch.quantity = -1;
  assert.ok((await call('confirmImport', mismatch)).error);
  const collision = importData(); collision.batch.id = 'b1';
  assert.ok((await call('confirmImport', collision)).error);
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 100);
});
test('damage uses authenticated actor, rejects negative/oversized quantities and duplicates', async () => {
  const payload = { report: { id: 'damage', code: 'BH001', batchId: 'b1', riceId: 'rice',
    quantity: 5, reason: 'moc', createdBy: 'admin', note: '' } };
  for (const quantity of [-1, '5', 101]) {
    assert.ok((await call('confirmDamage', { report: { ...payload.report, quantity } })).error);
  }
  assert.equal((await call('confirmDamage', payload)).result?.success, true);
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 95);
  assert.equal((await db.doc('damage_reports/damage').get()).data().reportedBy, 'staff');
  assert.equal((await call('confirmDamage', payload)).error.status, 'ALREADY_EXISTS');
});
test('multi-lot count recomputes differences, actor and immutable ledger', async () => {
  assert.equal((await call('completeCheck', checkData())).result?.success, true);
  const stored = (await db.doc('inventory_checks/check').get()).data();
  assert.equal(stored.createdBy, 'staff');
  assert.equal(stored.totalDifference, 0);
  assert.equal(stored.items[0].difference, -10);
  assert.equal((await db.doc('batches/b1').get()).data().quantity, 90);
  assert.equal((await db.doc('batches/b2').get()).data().quantity, 110);
  assert.equal((await db.collection('stock_movements').get()).size, 2);
  assert.equal((await call('completeCheck', checkData())).error.status, 'ALREADY_EXISTS');
});
test('stale count, duplicate lots and negative actual values leave all stock intact', async () => {
  const original = checkData().session.items;
  for (const items of [[{ ...original[0], actualQuantity: -1 }], [original[0], original[0]],
    [original[0], { ...original[1], expectedQuantity: 99 }]]) {
    assert.ok((await call('completeCheck', checkData({ items }))).error);
    assert.equal((await db.doc('batches/b1').get()).data().quantity, 100);
    assert.equal((await db.collection('inventory_checks').get()).size, 0);
  }
});

test('a disabled Firebase Auth account cannot reuse an otherwise valid token', async () => {
  await getAuth().updateUser('staff', { disabled: true });
  try {
    assert.ok((await call('confirmExport', exportData())).error);
    assert.equal((await db.doc('batches/b1').get()).data().quantity, 100);
  } finally {
    await getAuth().updateUser('staff', { disabled: false });
  }
});
