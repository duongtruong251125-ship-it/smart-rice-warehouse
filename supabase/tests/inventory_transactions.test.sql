begin;

select plan(20);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'supabase-rpc-test@example.invalid',
  'test-only-password-hash', pg_catalog.now(), pg_catalog.now(), pg_catalog.now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"RPC Test"}'::jsonb, false, false
);

insert into public.rice_products (
  id, code, name, category, unit, purchase_price, selling_price,
  minimum_stock, description, is_active
) values (
  'rice-test', 'R-TEST', 'Gạo kiểm thử', 'jasmine', 'kg', 10.50,
  15.00, 100, '', true
);
insert into public.suppliers (id, name, is_active)
values ('supplier-test', 'Nhà cung cấp kiểm thử', true);
insert into public.customers (id, name, customer_type, is_active)
values ('customer-test', 'Khách kiểm thử', 'retail', true);
insert into public.rice_characteristics (id, name, color_value, is_default)
values ('characteristic-test', 'Đặc tính kiểm thử', 4294967295, false);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated","email":"supabase-rpc-test@example.invalid"}',
  true
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select throws_ok(
  $$select public.confirm_import_receipt(
    '{"id":"inactive-import","code":"IMP-INACTIVE","supplierId":"supplier-test","riceId":"rice-test","quantity":1,"purchasePrice":10,"totalAmount":10,"batchCode":"INACTIVE-BATCH","date":"2026-10-29T00:00:00Z","manufactureDate":"2026-10-01T00:00:00Z","expiryDate":"2027-10-01T00:00:00Z"}'::jsonb,
    '{"id":"inactive-batch-id","code":"INACTIVE-BATCH","riceId":"rice-test","supplierId":"supplier-test","quantity":1,"manufactureDate":"2026-10-01T00:00:00Z","expiryDate":"2027-10-01T00:00:00Z"}'::jsonb
  )$$,
  '42501',
  'Active warehouse account required',
  'an inactive profile cannot confirm inventory transactions'
);

reset role;
update public.profiles set role = 'admin', is_active = true
where id = '10000000-0000-0000-0000-000000000001';
set local role authenticated;

select lives_ok(
  $$select public.save_rice_product(
    '{"id":"rice-test","code":"R-TEST","name":"Gạo kiểm thử","category":"jasmine","unit":"kg","purchasePrice":10.5,"sellingPrice":15,"minimumStock":100,"description":"","isActive":true,"characteristicIds":["characteristic-test"]}'::jsonb
  )$$,
  'rice product and characteristic links save atomically'
);
select is(
  (select count(*) from public.rice_product_characteristics where rice_id = 'rice-test'),
  1::bigint,
  'rice product characteristic links are synchronized'
);

select lives_ok(
  $$select public.confirm_import_receipt(
    '{"id":"imp-test","code":"IMP-TEST","supplierId":"supplier-test","riceId":"rice-test","quantity":120,"purchasePrice":10.5,"totalAmount":1260,"batchCode":"BATCH-TEST","date":"2026-10-29T00:00:00Z","manufactureDate":"2026-10-01T00:00:00Z","expiryDate":"2027-10-01T00:00:00Z"}'::jsonb,
    '{"id":"batch-test","code":"BATCH-TEST","riceId":"rice-test","supplierId":"supplier-test","quantity":120,"manufactureDate":"2026-10-01T00:00:00Z","expiryDate":"2027-10-01T00:00:00Z"}'::jsonb
  )$$,
  'valid import atomically creates a receipt, batch, code reservation, and ledger movement'
);
select is(
  (select quantity from public.batches where id = 'batch-test'),
  120::numeric,
  'imported quantity is added to the batch'
);
select is(
  (select quantity_delta from public.stock_movements where reference_id = 'imp-test'),
  120::numeric,
  'import movement records its positive stock delta'
);

select throws_ok(
  $$select public.confirm_export_receipt(
    '{"id":"exp-fail","code":"EXP-FAIL","customerId":"customer-test","riceId":"rice-test","quantity":999,"sellingPrice":15,"totalAmount":14985,"date":"2026-10-29T00:00:00Z","note":"","allocations":[{"batchId":"batch-test","allocatedQuantity":999}]}'::jsonb
  )$$,
  '23514',
  'Insufficient batch quantity',
  'export rejects quantities above the locked batch balance'
);
select ok(
  not exists (select 1 from public.export_receipts where id = 'exp-fail')
  and (select quantity = 120 from public.batches where id = 'batch-test'),
  'failed export rolls back its receipt and leaves stock unchanged'
);

select lives_ok(
  $$select public.confirm_export_receipt(
    '{"id":"exp-test","code":"EXP-TEST","customerId":"customer-test","riceId":"rice-test","riceName":"Gạo kiểm thử","quantity":10,"sellingPrice":15,"totalAmount":150,"date":"2026-10-29T00:00:00Z","note":"test","allocations":[{"batchId":"batch-test","allocatedQuantity":10}]}'::jsonb
  )$$,
  'valid export atomically records allocation and stock movement'
);
select is(
  (select quantity from public.batches where id = 'batch-test'),
  110::numeric,
  'export subtracts the allocated amount'
);
select is(
  (select status from public.batches where id = 'batch-test'),
  'available'::text,
  'export keeps a batch available above the low-stock threshold'
);
select is(
  (select allocated_quantity from public.export_receipt_allocations where receipt_id = 'exp-test'),
  10::numeric,
  'export allocation stores the server-calculated amount'
);

select lives_ok(
  $$select public.confirm_damage_report(
    '{"id":"dmg-test","code":"DMG-TEST","batchId":"batch-test","riceId":"rice-test","quantity":20,"reason":"moc","note":"damage test","createdAt":"2026-10-29T00:00:00Z","status":"confirmed"}'::jsonb
  )$$,
  'valid damage report atomically reduces stock and appends a ledger movement'
);
select is(
  (select quantity from public.batches where id = 'batch-test'),
  90::numeric,
  'damage quantity is deducted from the batch'
);
select is(
  (select status from public.batches where id = 'batch-test'),
  'lowStock'::text,
  'damage updates batch status when quantity crosses the low-stock threshold'
);

select lives_ok(
  $$select public.complete_inventory_check(
    '{"id":"check-test","code":"CHK-TEST","createdAt":"2026-10-29T00:00:00Z","status":"completed","items":[{"batchId":"batch-test","batchCode":"BATCH-TEST","riceName":"Gạo kiểm thử","expectedQuantity":90,"actualQuantity":0,"difference":-90,"reason":"haoHut","note":"count test"}],"totalItems":1,"totalDifference":-90,"note":"inventory test"}'::jsonb
  )$$,
  'valid inventory check atomically records the count and reconciles stock'
);
select is(
  (select quantity from public.batches where id = 'batch-test'),
  0::numeric,
  'inventory check reconciles batch quantity to the physical count'
);
select is(
  (select status from public.batches where id = 'batch-test'),
  'qualityHold'::text,
  'inventory check marks a zero-stock batch as quality hold'
);
select is(
  (select total_difference from public.inventory_checks where id = 'check-test'),
  -90::numeric,
  'inventory check total difference is calculated by the server'
);
select is(
  (select count(*) from public.stock_movements),
  4::bigint,
  'each successful stock change appends exactly one audit movement'
);

select * from finish();
rollback;
