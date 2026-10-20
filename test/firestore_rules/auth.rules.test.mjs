import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc, updateDoc, writeBatch, Timestamp } from 'firebase/firestore';

const projectId = 'demo-smart-rice-auth';
const endpoint = process.env.FIRESTORE_EMULATOR_HOST;
if (endpoint !== '127.0.0.1:8089') {
  throw new Error('Tests require the explicit local Firestore emulator at 127.0.0.1:8089.');
}
if (process.env.GCLOUD_PROJECT !== projectId) {
  throw new Error('Tests require the demo-smart-rice-auth project.');
}
let env;
const user = (role = 'staff', isActive = true) => ({
  email: 'user@example.com', displayName: 'User', role, isActive,
  createdAt: Timestamp.fromMillis(1), updatedAt: Timestamp.fromMillis(2),
});
const db = (uid) => env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();

before(async () => {
  env = await initializeTestEnvironment({ projectId,
    firestore: { host: '127.0.0.1', port: 8089,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const store = context.firestore();
    for (const [uid, role, active] of [
      ['admin', 'admin', true], ['staff', 'staff', true], ['pending', 'staff', false],
    ]) {
      await setDoc(doc(store, 'users', uid), { ...user(role, active), email: `${uid}@example.com` });
    }
    await setDoc(doc(store, 'batches', 'batch1'), { quantity: 100 });
  });
});
after(async () => { await env?.cleanup(); });

test('unauthenticated clients cannot read profiles or business data', async () => {
  const store = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(store, 'users', 'admin')));
  await assertFails(getDoc(doc(store, 'batches', 'batch1')));
});
test('staff can read own profile but cannot list or read another profile', async () => {
  await assertSucceeds(getDoc(doc(db('staff'), 'users', 'staff')));
  await assertFails(getDoc(doc(db('staff'), 'users', 'admin')));
  await assertFails(getDocs(collection(db('staff'), 'users')));
  await assertSucceeds(getDocs(collection(db('admin'), 'users')));
});
test('registration can create only its own pending staff profile', async () => {
  const store = db('new-user');
  const profile = { ...user('staff', false), email: 'new-user@example.com' };
  await assertFails(setDoc(doc(store, 'users', 'someone-else'), profile));
  await assertFails(setDoc(doc(store, 'users', 'new-user'), { ...profile, role: 'admin' }));
  await assertFails(setDoc(doc(store, 'users', 'new-user'), { ...profile, isActive: true }));
  await assertSucceeds(setDoc(doc(store, 'users', 'new-user'), profile));
});
test('staff cannot escalate role, activate itself or edit another profile', async () => {
  await assertFails(updateDoc(doc(db('staff'), 'users', 'staff'), { role: 'admin' }));
  await assertFails(updateDoc(doc(db('pending'), 'users', 'pending'), { isActive: true }));
  await assertFails(updateDoc(doc(db('staff'), 'users', 'pending'), { displayName: 'Changed' }));
});
test('only valid self name/timestamp updates are permitted', async () => {
  const ref = doc(db('staff'), 'users', 'staff');
  await assertSucceeds(updateDoc(ref, { displayName: 'Updated', updatedAt: Timestamp.now() }));
  await assertFails(updateDoc(ref, { displayName: '' }));
  await assertFails(updateDoc(ref, { updatedAt: 'invalid timestamp' }));
  await assertFails(updateDoc(ref, { email: 'another@example.com' }));
  await assertFails(updateDoc(ref, { injected: true }));
});
test('pending and blocked profiles cannot read or write business data', async () => {
  await assertFails(getDoc(doc(db('pending'), 'batches', 'batch1')));
  await assertFails(updateDoc(doc(db('pending'), 'batches', 'batch1'), { quantity: 1 }));
  await assertFails(updateDoc(doc(db('pending'), 'users', 'pending'), { displayName: 'Changed' }));
});

test('malformed roles never grant cloud access even with active true', async () => {
  const roles = ['admin\n', ' admin', 'admin ', 'staff\t', 'owner', 1, true, null];
  for (const [index, role] of roles.entries()) {
    const uid = `invalid-${index}`;
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', uid), user(role, true));
    });
    await assertFails(getDoc(doc(db(uid), 'batches', 'batch1')));
    await assertFails(getDocs(collection(db(uid), 'users')));
  }
  await env.withSecurityRulesDisabled(async (context) => {
    const { role, ...missingRole } = user();
    await setDoc(doc(context.firestore(), 'users', 'missing-role'), missingRole);
  });
  await assertFails(getDoc(doc(db('missing-role'), 'batches', 'batch1')));
});
test('active admin can change access, but cannot corrupt immutable identity or types', async () => {
  const ref = doc(db('admin'), 'users', 'staff');
  await assertSucceeds(updateDoc(ref, { role: 'admin', isActive: true, updatedAt: Timestamp.now() }));
  await assertFails(updateDoc(ref, { role: 'owner' }));
  await assertFails(updateDoc(ref, { isActive: 'true' }));
  await assertFails(updateDoc(ref, { email: 'replacement@example.com' }));
  await assertFails(updateDoc(ref, { createdAt: Timestamp.now() }));
});
test('blocking an already authenticated staff account immediately denies subsequent requests', async () => {
  const store = db('staff');
  await assertSucceeds(getDoc(doc(store, 'batches', 'batch1')));
  await assertSucceeds(updateDoc(doc(db('admin'), 'users', 'staff'), { isActive: false }));
  await assertFails(getDoc(doc(store, 'batches', 'batch1')));
  await assertFails(updateDoc(doc(store, 'batches', 'batch1'), { quantity: 10 }));
});

test('even active admin/staff cannot bypass the server for stock or ledger writes', async () => {
  for (const uid of ['admin', 'staff']) {
    const store = db(uid);
    for (const quantity of [-1, '10', 10]) {
      await assertFails(updateDoc(doc(store, 'batches', 'batch1'), { quantity }));
    }
    await assertFails(setDoc(doc(store, 'batches', 'new'), { quantity: 10 }));
    for (const path of ['import_receipts', 'export_receipts', 'damage_reports',
      'inventory_checks', 'stock_movements', 'batch_codes']) {
      await assertFails(setDoc(doc(store, path, 'forged'), {
        quantity: 10, performedBy: uid, referenceId: 'forged',
      }));
    }
    // Forging all three documents together does not turn client input trusted.
    const forged = writeBatch(store);
    forged.update(doc(store, 'batches', 'batch1'), { quantity: 90 });
    forged.set(doc(store, 'export_receipts', 'forged'), { quantity: 10, performedBy: uid });
    forged.set(doc(store, 'stock_movements', 'forged'), { quantityDelta: -10, performedBy: uid });
    await assertFails(forged.commit());
  }
});

test('location-only changes remain allowed but cannot smuggle a stock or identity change', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'warehouse_locations', 'active'), { isActive: true });
    await setDoc(doc(context.firestore(), 'warehouse_locations', 'inactive'), { isActive: false });
  });
  const ref = doc(db('staff'), 'batches', 'batch1');
  const move = { warehouseLocationId: 'active', locationName: 'A1',
    locationNameSnapshot: 'A1', updatedAt: Timestamp.now() };
  await assertSucceeds(updateDoc(ref, move));
  await assertFails(updateDoc(ref, { ...move, quantity: 99 }));
  await assertFails(updateDoc(ref, { ...move, riceId: 'different' }));
  await assertFails(updateDoc(ref, { ...move, warehouseLocationId: 'inactive' }));
  await assertFails(updateDoc(ref, { ...move, warehouseLocationId: 'missing' }));
});
