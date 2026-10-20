'use strict';
const { createHash } = require('node:crypto');
const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const collections = ['rice_characteristics', 'rice_products', 'suppliers', 'customers',
  'warehouse_locations', 'batches', 'import_receipts', 'export_receipts', 'damage_reports',
  'inventory_checks', 'inventory_snapshots'];
const fields = {
  rice_characteristics: 'name description colorValue isDefault createdAt updatedAt',
  rice_products: 'code name category unit purchasePrice sellingPrice minimumStock description isActive characteristicIds createdAt updatedAt',
  suppliers: 'name phone email address taxCode isActive createdAt updatedAt',
  customers: 'name phone address customerType isActive email note createdAt updatedAt',
  warehouse_locations: 'zone rack shelf code capacity currentBatchCount isActive description',
  batches: 'code riceId riceName quantity importDate manufactureDate expiryDate status supplierId supplierName warehouseLocationId locationName',
  import_receipts: 'code supplierId supplierName date riceId riceName quantity purchasePrice totalAmount batchCode manufactureDate expiryDate',
  export_receipts: 'code customerId customerName date riceId riceName quantity sellingPrice totalAmount note allocations',
  damage_reports: 'code batchId batchCode riceId riceName quantity reason note createdAt status',
  inventory_checks: 'code createdAt status items totalItems totalDifference completedAt note',
  inventory_snapshots: 'date totalQuantity totalValue note',
};
const dates = new Set('createdAt updatedAt date importDate manufactureDate expiryDate reportedAt completedAt'.split(' '));
function reject(message, code = 'invalid-argument') { throw new HttpsError(code, message); }
function identifier(value) {
  if (typeof value !== 'string' || !value || value.length > 200 || /[/]/.test(value) || ['.', '..'].includes(value)) reject('ID dữ liệu cũ không hợp lệ.');
  return value;
}
function finite(value, signed = false) {
  if (typeof value !== 'number' || !Number.isFinite(value) || Math.abs(value) > 1e12 || (!signed && value < 0)) reject('Dữ liệu cũ có số lượng/giá trị không hợp lệ.');
  return value;
}
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  return value;
}
function normalize(record) {
  if (!record || !collections.includes(record.collection)) reject('Collection migration không được phép.');
  const documentId = identifier(record.id);
  const raw = record.data;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) reject('Thiếu nội dung dữ liệu cũ.');
  const data = {};
  for (const key of fields[record.collection].split(' ')) {
    const value = raw[key];
    if (value == null) continue;
    if (dates.has(key)) {
      if (typeof value !== 'string' || !/(Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value))) reject('Ngày migration thiếu múi giờ hoặc không hợp lệ.');
      data[key] = Timestamp.fromDate(new Date(value));
    } else if (['isActive', 'isDefault'].includes(key)) {
      if (typeof value !== 'boolean') reject('Trạng thái dữ liệu cũ sai kiểu.');
      data[key] = value;
    } else if (['quantity', 'purchasePrice', 'sellingPrice', 'minimumStock', 'capacity',
      'currentBatchCount', 'totalAmount', 'totalItems', 'totalQuantity', 'totalValue', 'colorValue'].includes(key)) {
      data[key] = finite(value);
    } else if (key === 'totalDifference') {
      data[key] = finite(value, true);
    } else if (['allocations', 'items', 'characteristicIds'].includes(key)) {
      if (!Array.isArray(value) || value.length > 200) reject('Danh sách migration không hợp lệ.');
      data[key] = value.map((item) => {
        if (key === 'characteristicIds') return identifier(item);
        if (!item || typeof item !== 'object') reject('Chi tiết lịch sử không hợp lệ.');
        identifier(item.batchId);
        for (const numberKey of ['allocatedQuantity', 'batchInitialQuantity', 'batchRemainingQuantity', 'expectedQuantity', 'actualQuantity']) {
          if (numberKey in item) finite(item[numberKey]);
        }
        if ('difference' in item) finite(item.difference, true);
        return item;
      });
    } else {
      if (typeof value !== 'string' || value.length > 2000) reject('Nội dung migration sai kiểu.');
      data[key] = value;
    }
  }
  const kind = record.collection;
  if (['rice_characteristics', 'rice_products', 'suppliers', 'customers'].includes(kind) && !data.name?.trim()) reject('Thiếu tên danh mục.');
  if (kind === 'warehouse_locations' && (!data.code || !(data.capacity > 0))) reject('Vị trí cũ không hợp lệ.');
  if (kind === 'batches') {
    identifier(data.riceId);
    if (!data.code?.trim() || !data.manufactureDate || !data.expiryDate || !data.importDate ||
        !['available', 'lowStock', 'expired', 'qualityHold'].includes(data.status)) reject('Lô cũ thiếu thông tin bắt buộc.');
    finite(data.quantity);
    data.remainingQuantity = data.quantity;
  }
  if (['import_receipts', 'export_receipts', 'damage_reports'].includes(kind)) {
    identifier(data.riceId);
    if (!data.code || !(data.quantity > 0)) reject('Chứng từ cũ không hợp lệ.');
    if (kind !== 'damage_reports') {
      if (!data.date) reject('Chứng từ cũ thiếu ngày.');
      const price = finite(kind === 'import_receipts' ? data.purchasePrice : data.sellingPrice);
      finite(data.totalAmount);
      if (Math.abs(data.quantity * price - data.totalAmount) > 0.01) reject('Thành tiền chứng từ cũ không khớp.');
      data.status = 'confirmed';
    }
  }
  if (kind === 'damage_reports' && (!data.createdAt || !['confirmed', 'pending', 'rejected'].includes(data.status))) reject('Báo hỏng cũ không hợp lệ.');
  if (kind === 'inventory_checks' && (!['completed', 'cancelled', 'inProgress'].includes(data.status) || !data.createdAt || !Array.isArray(data.items))) reject('Kiểm kê cũ không hợp lệ.');
  if (kind === 'inventory_snapshots') { if (!data.date) reject('Snapshot cũ thiếu ngày.'); finite(data.totalQuantity); finite(data.totalValue); }
  return { collection: kind, id: documentId, data };
}

async function migrateLegacy(db, uid, input) {
  if (input?.approvedLegacyData !== true || !Array.isArray(input.records) || input.records.length > 1000 ||
      Buffer.byteLength(JSON.stringify(input.records)) > 2 * 1024 * 1024) reject('Cần xác nhận dữ liệu cũ là dữ liệu thật (tối đa 1000 bản ghi/2 MiB).');
  const records = input.records.map(normalize).sort((a, b) =>
    collections.indexOf(a.collection) - collections.indexOf(b.collection) || a.id.localeCompare(b.id));
  const seen = new Set();
  const codes = new Set();
  for (const record of records) {
    const key = `${record.collection}/${record.id}`;
    if (seen.has(key)) reject('Dữ liệu nguồn bị trùng ID.');
    seen.add(key);
    if (record.collection === 'batches') {
      const code = record.data.code.trim().toLowerCase();
      if (codes.has(code)) reject('Dữ liệu nguồn có mã lô trùng.');
      codes.add(code);
    }
  }
  // Hash raw canonical JSON, not server timestamps or a caller-provided run ID.
  const hash = createHash('sha256').update(JSON.stringify(canonical(input.records))).digest('hex');
  const runId = `legacy_v1_${hash}`;
  const runRef = db.doc(`migration_runs/${runId}`);
  return db.runTransaction(async (tx) => {
    const profile = await tx.get(db.doc(`users/${uid}`));
    if (!profile.exists || profile.data().isActive !== true || profile.data().role !== 'admin') reject('Chỉ admin đang hoạt động được chuyển dữ liệu cũ.', 'permission-denied');
    const stored = await tx.get(runRef);
    const previous = stored.data();
    if (previous && (previous.manifestHash !== hash || !Number.isInteger(previous.nextIndex) || previous.nextIndex < 0 || previous.nextIndex > records.length)) reject('Trạng thái migration không hợp lệ.', 'failed-precondition');
    if (previous?.status === 'completed') return { ...previous, runId };
    const start = previous?.nextIndex ?? 0;
    const chunk = records.slice(start, start + 20);
    const writes = [];
    let skipped = previous?.skipped ?? 0;
    let inserted = previous?.inserted ?? 0;
    const now = Timestamp.now();
    for (const record of chunk) {
      const ref = db.collection(record.collection).doc(record.id);
      if ((await tx.get(ref)).exists) { skipped++; continue; }
      const data = { ...record.data, legacyMigrationRun: runId, legacyImportedBy: uid };
      if (['import_receipts', 'export_receipts', 'damage_reports', 'inventory_checks'].includes(record.collection)) data.performedBy = uid;
      if (record.collection === 'damage_reports') { data.reportedBy = uid; data.reportedAt = data.createdAt; }
      if (record.collection === 'inventory_checks') data.createdBy = uid;
      if (record.collection === 'batches') {
        // Earlier chunks may have already imported the required catalog.
        // Same-chunk catalog writes are validated against the immutable manifest.
        const riceExists = (await tx.get(db.doc(`rice_products/${data.riceId}`))).exists;
        if (!riceExists && !seen.has(`rice_products/${data.riceId}`)) reject('Lô cũ thiếu loại gạo.', 'failed-precondition');
        const reservation = db.collection('batch_codes').doc(createHash('sha256').update(data.code.trim().toLowerCase()).digest('hex'));
        const reserved = await tx.get(reservation);
        if (reserved.exists && reserved.data().batchId !== record.id) reject('Mã lô đã thuộc lô cloud khác.', 'failed-precondition');
        const remote = await tx.get(db.collection('batches'));
        if (remote.docs.some((doc) => doc.id !== record.id && doc.data().code?.trim().toLowerCase() === data.code.trim().toLowerCase())) reject('Mã lô trùng dữ liệu cloud.', 'failed-precondition');
        const movement = db.doc(`stock_movements/mov_legacy_${record.id}`);
        if ((await tx.get(movement)).exists) reject('Sổ khởi tạo lô đã tồn tại.', 'failed-precondition');
        if (!reserved.exists) writes.push([reservation, { batchId: record.id, code: data.code }]);
        writes.push([movement, { type: 'migration', batchId: record.id, riceId: data.riceId,
          quantityBefore: 0, quantityAfter: data.quantity, quantityDelta: data.quantity,
          referenceType: 'migration_run', referenceId: runId, performedBy: uid, createdAt: now,
          note: 'Số dư đầu kỳ từ SQLite cũ đã được xác nhận là dữ liệu thật; không cộng lại lịch sử phiếu.' }]);
      }
      writes.push([ref, data]);
      inserted++;
    }
    const nextIndex = start + chunk.length;
    const state = { manifestHash: hash, nextIndex, total: records.length, inserted, skipped,
      status: nextIndex === records.length ? 'completed' : 'in_progress',
      performedBy: uid, updatedAt: now };
    for (const [ref, data] of writes) tx.create(ref, data);
    // Reservation can already point to the correct imported lot.
    tx.set(runRef, state);
    return { runId, ...state };
  });
}
module.exports = { migrateLegacy };
