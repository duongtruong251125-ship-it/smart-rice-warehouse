'use strict';
const { Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { createHash } = require('node:crypto');
const EPS = 0.0001;

function fail(message, code = 'failed-precondition') { throw new HttpsError(code, message); }
function text(value, label, max = 200) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
    fail(`${label} không hợp lệ.`, 'invalid-argument');
  }
  return value.trim();
}
function id(value) {
  const result = text(value, 'ID');
  if (result.includes('/') || result === '.' || result === '..') fail('ID không hợp lệ.', 'invalid-argument');
  return result;
}
function number(value, label, positive = false) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1e12 || (positive && value === 0)) {
    fail(`${label} phải là số hữu hạn ${positive ? 'dương' : 'không âm'}.`, 'invalid-argument');
  }
  return value;
}
function date(value, label) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T/.test(value) ||
      !/(Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value))) {
    fail(`${label} không hợp lệ.`, 'invalid-argument');
  }
  return Timestamp.fromDate(new Date(value));
}
function note(value) {
  if (value == null) return '';
  if (typeof value !== 'string' || value.length > 2000) fail('Ghi chú không hợp lệ.', 'invalid-argument');
  return value.trim();
}
function array(value, label) {
  // Firestore's atomic write limit is 500; each batch needs a stock + ledger write.
  if (!Array.isArray(value) || value.length === 0 || value.length > 200) {
    fail(`${label} cần từ 1 đến 200 mục.`, 'invalid-argument');
  }
  return value;
}
function heldOrExpired(batch, now) {
  const expiry = batch.expiryDate?.toMillis?.();
  if (!Number.isFinite(expiry)) fail('Lô có hạn dùng không hợp lệ.');
  // Dates entered by the app are calendar dates in Vietnam (UTC+7).
  const day = (ms) => Math.floor((ms + 7 * 3600000) / 86400000);
  return !['available', 'lowStock'].includes(batch.status) || day(expiry) < day(now.toMillis());
}
function batchData(snapshot) {
  if (!snapshot.exists) fail('Lô hàng không tồn tại.');
  const batch = snapshot.data();
  number(batch.quantity, 'Tồn kho');
  if (batch.remainingQuantity != null && batch.remainingQuantity !== batch.quantity) fail('Lô có số dư không nhất quán.');
  return batch;
}
function money(data, priceKey) {
  const price = number(data[priceKey], 'Đơn giá');
  const total = number(data.totalAmount, 'Thành tiền');
  if (!Number.isFinite(data.quantity * price) || Math.abs(total - data.quantity * price) > 0.01) {
    fail('Thành tiền không khớp số lượng và đơn giá.', 'invalid-argument');
  }
  return { [priceKey]: price, totalAmount: total };
}

async function executeInventory(db, uid, operation, input, now = Timestamp.now()) {
  id(uid);
  if (!input || typeof input !== 'object' || Array.isArray(input)) fail('Thiếu chứng từ.', 'invalid-argument');
  const kind = {
    confirmImport: ['import_receipts', 'import_receipt', 'import', 'imp'],
    confirmExport: ['export_receipts', 'export_receipt', 'export', 'exp'],
    confirmDamage: ['damage_reports', 'damage_report', 'damage', 'dmg'],
    completeCheck: ['inventory_checks', 'inventory_check', 'inventoryCheck', 'chk'],
  }[operation];
  if (!kind) fail('Giao dịch không hợp lệ.', 'invalid-argument');
  const data = input.receipt ?? input.report ?? input.session;
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail('Thiếu chứng từ.', 'invalid-argument');
  const documentId = id(data.id);
  const code = text(data.code, 'Mã chứng từ', 100);
  const ref = db.collection(kind[0]).doc(documentId);

  return db.runTransaction(async (tx) => {
    // Every read (including the live access profile) precedes every write.
    const profile = await tx.get(db.collection('users').doc(uid));
    if (!profile.exists || profile.data().isActive !== true || !['admin', 'staff'].includes(profile.data().role)) {
      fail('Tài khoản chưa được cấp quyền hoặc đã bị khóa.', 'permission-denied');
    }
    const previous = await tx.get(ref);
    if (previous.exists) fail('Chứng từ này đã được xác nhận.', 'already-exists');
    const writes = [];
    const extraWrites = [];
    let record;

    if (operation === 'confirmImport') {
      const requested = input.batch;
      if (!requested || typeof requested !== 'object') fail('Thiếu lô nhập.', 'invalid-argument');
      const quantity = number(data.quantity, 'Số lượng nhập', true);
      const riceId = id(data.riceId);
      const supplierId = id(data.supplierId);
      const batchCode = text(data.batchCode, 'Mã lô', 100);
      if (requested.riceId !== riceId || requested.supplierId !== supplierId ||
          text(requested.code, 'Mã lô', 100) !== batchCode || requested.quantity !== quantity) {
        fail('Lô và phiếu nhập không khớp.', 'invalid-argument');
      }
      const manufacture = date(data.manufactureDate, 'Ngày sản xuất');
      const expiry = date(data.expiryDate, 'Hạn dùng');
      if (manufacture.toMillis() > expiry.toMillis()) fail('Hạn dùng trước ngày sản xuất.', 'invalid-argument');
      if (date(requested.manufactureDate, 'Ngày sản xuất lô').toMillis() !== manufacture.toMillis() ||
          date(requested.expiryDate, 'Hạn dùng lô').toMillis() !== expiry.toMillis()) fail('Ngày lô và phiếu không khớp.', 'invalid-argument');
      const rice = await tx.get(db.collection('rice_products').doc(riceId));
      const supplier = await tx.get(db.collection('suppliers').doc(supplierId));
      if (!rice.exists || rice.data().isActive === false || !supplier.exists || supplier.data().isActive === false) {
        fail('Gạo hoặc nhà cung cấp không tồn tại/không hoạt động.');
      }
      const key = createHash('sha256').update(batchCode.toLowerCase()).digest('hex');
      const reservation = db.collection('batch_codes').doc(key);
      const reserved = await tx.get(reservation);
      // Legacy data has no normalized code index. Read inside the transaction,
      // never select a legacy candidate from a stale client snapshot.
      const candidates = reserved.exists
        ? [await tx.get(db.collection('batches').doc(id(reserved.data().batchId)))]
        : (await tx.get(db.collection('batches'))).docs.filter((s) =>
          typeof s.data().code === 'string' && s.data().code.trim().toLowerCase() === batchCode.toLowerCase());
      if (candidates.length > 1) fail('Mã lô bị trùng; cần đối soát trước khi nhập.');
      const existing = candidates[0];
      let targetId;
      let before = 0;
      let batch;
      if (existing) {
        batch = batchData(existing);
        if (batch.code.trim().toLowerCase() !== batchCode.toLowerCase() || batch.riceId !== riceId ||
            batch.supplierId !== supplierId || batch.manufactureDate?.toMillis?.() !== manufacture.toMillis() ||
            batch.expiryDate?.toMillis?.() !== expiry.toMillis()) fail('Mã lô thuộc lô khác.');
        targetId = existing.id;
        before = batch.quantity;
      } else {
        targetId = id(requested.id);
        const target = await tx.get(db.collection('batches').doc(targetId));
        if (target.exists) fail('ID lô đã tồn tại với mã khác.');
        const expired = Math.floor((expiry.toMillis() + 7 * 3600000) / 86400000) <
          Math.floor((now.toMillis() + 7 * 3600000) / 86400000);
        batch = { code: batchCode, riceId, riceName: rice.data().name,
          supplierId, supplierName: supplier.data().name,
          importDate: date(data.date, 'Ngày nhập'), manufactureDate: manufacture,
          expiryDate: expiry, status: expired ? 'expired' : (quantity <= 100 ? 'lowStock' : 'available'), createdAt: now };
      }
      const after = number(before + quantity, 'Tồn kho sau nhập');
      writes.push({ batchId: targetId, batch, before, after });
      extraWrites.push([reservation, { batchId: targetId, code: batchCode }]);
      record = { code, supplierId, supplierName: supplier.data().name,
        riceId, riceName: rice.data().name, quantity, batchCode,
        date: date(data.date, 'Ngày nhập'), manufactureDate: manufacture,
        expiryDate: expiry, ...money(data, 'purchasePrice'), status: 'confirmed' };
    } else if (operation === 'confirmExport') {
      const quantity = number(data.quantity, 'Số lượng xuất', true);
      const riceId = id(data.riceId);
      const customerId = id(data.customerId);
      const customer = await tx.get(db.collection('customers').doc(customerId));
      if (!customer.exists || customer.data().isActive === false) fail('Khách hàng không hoạt động.');
      const requested = new Map();
      for (const allocation of array(data.allocations, 'Phân bổ lô')) {
        const batchId = id(allocation.batchId);
        requested.set(batchId, number((requested.get(batchId) ?? 0) +
          number(allocation.allocatedQuantity, 'Số lượng phân bổ', true), 'Tổng phân bổ', true));
      }
      if (Math.abs([...requested.values()].reduce((a, b) => a + b, 0) - quantity) > EPS) fail('Tổng phân bổ không bằng số lượng xuất.', 'invalid-argument');
      const allocations = [];
      for (const [batchId, amount] of requested) {
        const batch = batchData(await tx.get(db.collection('batches').doc(batchId)));
        if (batch.riceId !== riceId || heldOrExpired(batch, now)) fail('Lô sai loại gạo, tạm giữ hoặc hết hạn.');
        if (amount > batch.quantity + EPS) fail('Không đủ tồn kho.');
        const after = Math.max(0, batch.quantity - amount);
        writes.push({ batchId, batch, before: batch.quantity, after });
        allocations.push({ batchId, batchCode: batch.code, allocatedQuantity: amount,
          batchInitialQuantity: batch.quantity, batchRemainingQuantity: after,
          expiryDate: batch.expiryDate.toDate().toISOString() });
      }
      record = { code, customerId, customerName: customer.data().name,
        riceId, riceName: writes[0].batch.riceName, quantity,
        date: date(data.date, 'Ngày xuất'), ...money(data, 'sellingPrice'),
        note: note(data.note), allocations, status: 'confirmed' };
    } else if (operation === 'confirmDamage') {
      const batchId = id(data.batchId);
      const quantity = number(data.quantity, 'Số lượng hỏng', true);
      const batch = batchData(await tx.get(db.collection('batches').doc(batchId)));
      if (data.riceId !== batch.riceId || quantity > batch.quantity + EPS) fail('Lô không khớp hoặc vượt tồn kho.');
      const reasons = ['baoRach', 'baoUot', 'moc', 'conTrung', 'haoHut', 'khac'];
      if (!reasons.includes(data.reason)) fail('Lý do hỏng không hợp lệ.', 'invalid-argument');
      writes.push({ batchId, batch, before: batch.quantity, after: Math.max(0, batch.quantity - quantity) });
      record = { code, batchId, batchCode: batch.code, riceId: batch.riceId,
        riceName: batch.riceName, quantity, reason: data.reason, note: note(data.note),
        reportedBy: uid, reportedAt: now, createdAt: now, status: 'confirmed' };
    } else {
      const seen = new Set();
      const items = [];
      for (const item of array(data.items, 'Kiểm kê')) {
        const batchId = id(item.batchId);
        if (seen.has(batchId)) fail('Lô bị lặp trong kiểm kê.', 'invalid-argument');
        seen.add(batchId);
        const expected = number(item.expectedQuantity, 'Số lượng dự kiến');
        const actual = number(item.actualQuantity, 'Số lượng thực tế');
        const batch = batchData(await tx.get(db.collection('batches').doc(batchId)));
        if (Math.abs(batch.quantity - expected) > 0.001) fail('Tồn kho đã đổi sau khi đếm.');
        const reasons = ['none', 'haoHut', 'baoRach', 'saiDuLieu', 'matHang', 'khac'];
        if (!reasons.includes(item.reason)) fail('Lý do kiểm kê không hợp lệ.', 'invalid-argument');
        const difference = actual - expected;
        items.push({ batchId, batchCode: batch.code, riceName: batch.riceName,
          expectedQuantity: expected, actualQuantity: actual, difference,
          reason: item.reason, note: note(item.note) });
        if (Math.abs(difference) > 0.001) writes.push({ batchId, batch, before: expected, after: actual });
      }
      record = { code, createdBy: uid, createdAt: now, completedAt: now,
        status: 'completed', items, totalItems: items.length,
        totalDifference: items.reduce((sum, item) => sum + item.difference, 0), note: note(data.note) };
    }

    // Check immutable ledger IDs before any write, including legacy orphan data.
    const movements = writes.map((write) => ({ ...write,
      movementId: `mov_${kind[3]}_${documentId}_${write.batchId}` }));
    for (const write of movements) {
      if ((await tx.get(db.collection('stock_movements').doc(write.movementId))).exists) fail('Biến động đã tồn tại.', 'already-exists');
    }
    for (const write of movements) {
      const stock = { ...write.batch, quantity: write.after, remainingQuantity: write.after, updatedAt: now };
      // A count/import must never silently release a quality hold.
      if (operation === 'confirmExport') stock.status = write.after <= 100 ? 'lowStock' : 'available';
      tx.set(db.collection('batches').doc(write.batchId), stock);
      tx.create(db.collection('stock_movements').doc(write.movementId), {
        type: kind[2], batchId: write.batchId, riceId: write.batch.riceId,
        quantityBefore: write.before, quantityAfter: write.after,
        quantityDelta: write.after - write.before,
        referenceType: kind[1], referenceId: documentId,
        performedBy: uid, createdAt: now, note: note(data.note),
      });
    }
    for (const [target, value] of extraWrites) tx.set(target, value);
    tx.create(ref, { ...record, performedBy: uid });
    return { success: true, id: documentId };
  });
}
module.exports = { executeInventory };
