'use strict';
const { before, beforeEach, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { getApps, initializeApp, deleteApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const projectId = 'demo-smart-rice-auth';
if (
  process.env.GCLOUD_PROJECT !== projectId ||
  process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8089' ||
  process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9098'
) {
  throw new Error('Legacy migration tests require explicit local Firestore/Auth emulators and demo project.');
}

const app = getApps().length > 0 ? getApps()[0] : initializeApp({ projectId });
const db = getFirestore(app);
const now = new Date('2026-10-20T00:00:00.000Z');
const isoDate = now.toISOString();
const expiryIso = new Date('2027-10-20T00:00:00.000Z').toISOString();

let adminToken;
let staffToken;

async function callMigration(data, tokenToUse) {
  const headers = { 'Content-Type': 'application/json' };
  if (tokenToUse) {
    headers.Authorization = `Bearer ${tokenToUse}`;
  }
  const response = await fetch(`http://127.0.0.1:5002/${projectId}/us-central1/migrateLegacyWarehouse`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });
  return response.json();
}

async function getAuthToken(email, password, uid) {
  const auth = getAuth(app);
  try {
    await auth.getUser(uid);
  } catch {
    await auth.createUser({ uid, email, password });
  }
  const response = await fetch(
    'http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  const data = await response.json();
  assert.ok(data.idToken, `Auth emulator must return an ID token for ${email}`);
  return data.idToken;
}

before(async () => {
  adminToken = await getAuthToken('admin-mig@example.com', 'admin-pass', 'admin_mig');
  staffToken = await getAuthToken('staff-mig@example.com', 'staff-pass', 'staff_mig');
});

beforeEach(async () => {
  const reset = await fetch(
    `http://127.0.0.1:8089/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
  assert.equal(reset.ok, true);

  const batch = db.batch();
  batch.set(db.doc('users/admin_mig'), { role: 'admin', isActive: true, email: 'admin-mig@example.com' });
  batch.set(db.doc('users/staff_mig'), { role: 'staff', isActive: true, email: 'staff-mig@example.com' });
  await batch.commit();
});

after(async () => {
  await deleteApp(app);
});

function sampleManifest() {
  return {
    approvedLegacyData: true,
    records: [
      {
        collection: 'rice_products',
        id: 'rice_legacy_1',
        data: {
          code: 'ST25-LEGACY',
          name: 'Gạo ST25 Ông Cua',
          category: 'Gạo thơm đặc sản',
          unit: 'kg',
          purchasePrice: 20000,
          sellingPrice: 28000,
          minimumStock: 500,
          isActive: true,
          createdAt: isoDate,
          updatedAt: isoDate,
        },
      },
      {
        collection: 'warehouse_locations',
        id: 'loc_legacy_1',
        data: {
          zone: 'A',
          rack: '1',
          shelf: '1',
          code: 'A1-01',
          capacity: 10000,
          currentBatchCount: 1,
          isActive: true,
        },
      },
      {
        collection: 'batches',
        id: 'batch_legacy_1',
        data: {
          code: 'LO-LEGACY-001',
          riceId: 'rice_legacy_1',
          riceName: 'Gạo ST25 Ông Cua',
          quantity: 1500,
          status: 'available',
          importDate: isoDate,
          manufactureDate: isoDate,
          expiryDate: expiryIso,
        },
      },
      {
        collection: 'import_receipts',
        id: 'imp_legacy_1',
        data: {
          code: 'PN-LEGACY-001',
          riceId: 'rice_legacy_1',
          riceName: 'Gạo ST25 Ông Cua',
          date: isoDate,
          quantity: 1500,
          purchasePrice: 20000,
          totalAmount: 30000000,
          batchCode: 'LO-LEGACY-001',
          manufactureDate: isoDate,
          expiryDate: expiryIso,
        },
      },
    ],
  };
}

test('unauthenticated legacy migration is rejected', async () => {
  const res = await callMigration(sampleManifest(), null);
  assert.equal(res.error?.status, 'UNAUTHENTICATED');
});

test('non-admin role is rejected with permission-denied', async () => {
  const res = await callMigration(sampleManifest(), staffToken);
  assert.equal(res.error?.status, 'PERMISSION_DENIED');
});

test('inactive admin is rejected with permission-denied', async () => {
  await db.doc('users/admin_mig').update({ isActive: false });
  const res = await callMigration(sampleManifest(), adminToken);
  assert.equal(res.error?.status, 'PERMISSION_DENIED');
});

test('unapproved legacy data flag is rejected with invalid-argument', async () => {
  const manifest = sampleManifest();
  manifest.approvedLegacyData = false;
  const res = await callMigration(manifest, adminToken);
  assert.equal(res.error?.status, 'INVALID_ARGUMENT');
});

test('valid legacy manifest creates records, reservation and opening balance ledger', async () => {
  const manifest = sampleManifest();
  const res = await callMigration(manifest, adminToken);
  assert.equal(res.result?.status, 'completed');
  assert.equal(res.result?.inserted, 4);
  assert.equal(res.result?.skipped, 0);

  // Verify batch document
  const batchDoc = await db.doc('batches/batch_legacy_1').get();
  assert.equal(batchDoc.exists, true);
  const batchData = batchDoc.data();
  assert.equal(batchData.quantity, 1500);
  assert.equal(batchData.remainingQuantity, 1500);
  assert.equal(batchData.legacyImportedBy, 'admin_mig');

  // Verify batch code reservation
  const reservation = await db.collection('batch_codes').get();
  assert.equal(reservation.size, 1);
  assert.equal(reservation.docs[0].data().batchId, 'batch_legacy_1');

  // Verify opening balance stock movement
  const movementDoc = await db.doc('stock_movements/mov_legacy_batch_legacy_1').get();
  assert.equal(movementDoc.exists, true);
  const movement = movementDoc.data();
  assert.equal(movement.type, 'migration');
  assert.equal(movement.quantityBefore, 0);
  assert.equal(movement.quantityDelta, 1500);
  assert.equal(movement.quantityAfter, 1500);
  assert.equal(movement.performedBy, 'admin_mig');
  assert.equal(movement.referenceType, 'migration_run');
});

test('preserves existing cloud records and never overwrites them', async () => {
  // Pre-seed an existing cloud rice product with cloud-specific description
  await db.doc('rice_products/rice_legacy_1').set({
    name: 'Gạo ST25 Cloud Đã Sửa',
    description: 'Bản ghi này đã tồn tại trên Firestore trước khi chuyển dữ liệu',
    isActive: true,
  });

  const manifest = sampleManifest();
  const res = await callMigration(manifest, adminToken);
  assert.equal(res.result?.status, 'completed');
  assert.equal(res.result?.skipped, 1); // rice_legacy_1 skipped

  // Verify the existing cloud document was untouched
  const riceDoc = await db.doc('rice_products/rice_legacy_1').get();
  assert.equal(riceDoc.data().name, 'Gạo ST25 Cloud Đã Sửa');
  assert.equal(riceDoc.data().description, 'Bản ghi này đã tồn tại trên Firestore trước khi chuyển dữ liệu');
});

test('idempotent rerun skips already completed records', async () => {
  const manifest = sampleManifest();
  const first = await callMigration(manifest, adminToken);
  assert.equal(first.result?.status, 'completed');

  // Second run with the same manifest
  const second = await callMigration(manifest, adminToken);
  if (second.error) {
    console.error('Second run error:', JSON.stringify(second.error));
  }
  assert.equal(second.result?.status, 'completed');
  assert.equal(second.result?.runId, first.result?.runId);
});
