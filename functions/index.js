'use strict';
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onInit } = require('firebase-functions/v2/core');
let auth;
let db;
let executeInventory;
let migrateLegacy;
// Keep code discovery lightweight on slower local/CI machines. SDK loading and
// service construction happen once per runtime, not during deployment discovery.
onInit(() => {
  const { initializeApp } = require('firebase-admin/app');
  initializeApp();
  auth = require('firebase-admin/auth').getAuth();
  db = require('firebase-admin/firestore').getFirestore();
  executeInventory = require('./inventory').executeInventory;
  migrateLegacy = require('./legacy-migration').migrateLegacy;
});

for (const operation of ['confirmImport', 'confirmExport', 'confirmDamage', 'completeCheck', 'migrateLegacyWarehouse']) {
  exports[operation] = onCall({ region: 'us-central1', maxInstances: 10 }, async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập.');
    // Do not trust an actor supplied in request.data or a cached client profile.
    const account = await auth.getUser(request.auth.uid);
    if (account.disabled) throw new HttpsError('permission-denied', 'Tài khoản đã bị khóa.');
    return operation === 'migrateLegacyWarehouse'
      ? migrateLegacy(db, request.auth.uid, request.data)
      : executeInventory(db, request.auth.uid, operation, request.data);
  });
}
