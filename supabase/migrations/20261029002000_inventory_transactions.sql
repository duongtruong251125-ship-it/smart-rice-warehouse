-- Atomic inventory RPCs enforce the trusted server-side transaction boundary:
-- clients submit a request, while the database locks stock and authors the
-- receipt, batch quantities, allocation snapshots, and immutable ledger.

create or replace function public.confirm_import_receipt(
  payload_receipt jsonb,
  payload_batch jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  receipt_id text := btrim(payload_receipt ->> 'id');
  receipt_code text := btrim(payload_receipt ->> 'code');
  batch_id text := btrim(payload_batch ->> 'id');
  batch_code text := btrim(payload_receipt ->> 'batchCode');
  rice_id text := btrim(payload_receipt ->> 'riceId');
  supplier_id text := btrim(payload_receipt ->> 'supplierId');
  amount numeric(18, 4) := (payload_receipt ->> 'quantity')::numeric;
  unit_price numeric(18, 2) := (payload_receipt ->> 'purchasePrice')::numeric;
  total numeric(18, 2) := (payload_receipt ->> 'totalAmount')::numeric;
  receipt_date date := left(payload_receipt ->> 'date', 10)::date;
  manufacture date := left(payload_receipt ->> 'manufactureDate', 10)::date;
  expiry date := left(payload_receipt ->> 'expiryDate', 10)::date;
  current_batch public.batches%rowtype;
  rice public.rice_products%rowtype;
  supplier public.suppliers%rowtype;
  before_quantity numeric(18, 4) := 0;
  after_quantity numeric(18, 4);
  target_batch_id text;
  new_status text;
begin
  if actor is null or not public.current_profile_is_active() then
    raise exception using errcode = '42501', message = 'Active warehouse account required';
  end if;
  if jsonb_typeof(payload_receipt) is distinct from 'object'
     or jsonb_typeof(payload_batch) is distinct from 'object'
     or receipt_id is null or receipt_id = '' or receipt_code is null or receipt_code = ''
     or batch_id is null or batch_id = '' or batch_code is null or batch_code = ''
     or rice_id is null or rice_id = '' or supplier_id is null or supplier_id = '' then
    raise exception using errcode = '22023', message = 'Import receipt or batch is invalid';
  end if;
  if position('/' in receipt_id) > 0 or position('/' in batch_id) > 0
     or amount <= 0 or unit_price < 0 or total < 0
     or abs(total - amount * unit_price) > 0.01
     or manufacture > expiry then
    raise exception using errcode = '22023', message = 'Import values are invalid';
  end if;
  if payload_batch ->> 'riceId' is distinct from rice_id
     or payload_batch ->> 'supplierId' is distinct from supplier_id
     or lower(btrim(payload_batch ->> 'code')) <> lower(batch_code)
     or (payload_batch ->> 'quantity')::numeric <> amount
     or left(payload_batch ->> 'manufactureDate', 10)::date <> manufacture
     or left(payload_batch ->> 'expiryDate', 10)::date <> expiry then
    raise exception using errcode = '22023', message = 'Import receipt and batch do not match';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(lower(batch_code), 0));
  select * into rice from public.rice_products where id = rice_id and is_active for share;
  if not found then raise exception using errcode = '23503', message = 'Rice product is missing or inactive'; end if;
  select * into supplier from public.suppliers where id = supplier_id and is_active for share;
  if not found then raise exception using errcode = '23503', message = 'Supplier is missing or inactive'; end if;

  select * into current_batch from public.batches
  where lower(btrim(code)) = lower(batch_code) for update;
  if found then
    if current_batch.rice_id <> rice_id or current_batch.supplier_id is distinct from supplier_id
       or current_batch.manufacture_date <> manufacture or current_batch.expiry_date <> expiry then
      raise exception using errcode = '23514', message = 'Batch code belongs to a different batch';
    end if;
    target_batch_id := current_batch.id;
    before_quantity := current_batch.quantity;
  else
    if exists (select 1 from public.batches where id = batch_id) then
      raise exception using errcode = '23505', message = 'Batch ID already exists';
    end if;
    target_batch_id := batch_id;
  end if;

  if exists (select 1 from public.import_receipts where id = receipt_id or code = receipt_code) then
    raise exception using errcode = '23505', message = 'Import receipt already exists';
  end if;
  after_quantity := before_quantity + amount;
  if current_batch.id is null then
    new_status := case
      when expiry < (pg_catalog.now() at time zone 'Asia/Ho_Chi_Minh')::date then 'expired'
      when after_quantity <= 100 then 'lowStock'
      else 'available'
    end;
    insert into public.batches (
      id, code, rice_id, rice_name, quantity, import_date, manufacture_date,
      expiry_date, status, supplier_id, supplier_name
    ) values (
      target_batch_id, batch_code, rice_id, rice.name, after_quantity,
      receipt_date, manufacture, expiry, new_status, supplier_id, supplier.name
    );
  else
    update public.batches set quantity = after_quantity
    where id = target_batch_id;
  end if;

  insert into public.batch_codes (code_key, code, batch_id)
  values (lower(batch_code), batch_code, target_batch_id)
  on conflict (code_key) do nothing;
  if exists (
    select 1 from public.batch_codes as reservation
    where reservation.code_key = lower(batch_code)
      and reservation.batch_id <> target_batch_id
  ) then
    raise exception using errcode = '23505', message = 'Batch code reservation belongs to another batch';
  end if;

  insert into public.import_receipts (
    id, code, supplier_id, supplier_name, date, rice_id, rice_name, quantity,
    purchase_price, total_amount, batch_code, manufacture_date, expiry_date,
    status, performed_by
  ) values (
    receipt_id, receipt_code, supplier_id, supplier.name, receipt_date,
    rice_id, rice.name, amount, unit_price, total, batch_code, manufacture,
    expiry, 'confirmed', actor::text
  );

  insert into public.stock_movements (
    id, type, batch_id, rice_id, quantity_delta, quantity_before,
    quantity_after, reference_type, reference_id, performed_by, note
  ) values (
    'mov_imp_' || receipt_id || '_' || target_batch_id, 'import',
    target_batch_id, rice_id, amount, before_quantity, after_quantity,
    'import_receipt', receipt_id, actor::text, ''
  );
end;
$$;

create or replace function public.confirm_export_receipt(payload_receipt jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  receipt_id text := btrim(payload_receipt ->> 'id');
  receipt_code text := btrim(payload_receipt ->> 'code');
  customer_id text := btrim(payload_receipt ->> 'customerId');
  rice_id text := btrim(payload_receipt ->> 'riceId');
  amount numeric(18, 4) := (payload_receipt ->> 'quantity')::numeric;
  unit_price numeric(18, 2) := (payload_receipt ->> 'sellingPrice')::numeric;
  total numeric(18, 2) := (payload_receipt ->> 'totalAmount')::numeric;
  receipt_date date := left(payload_receipt ->> 'date', 10)::date;
  allocations jsonb := payload_receipt -> 'allocations';
  allocation jsonb;
  batch_row public.batches%rowtype;
  customer public.customers%rowtype;
  rice public.rice_products%rowtype;
  allocated numeric(18, 4);
  remaining numeric(18, 4);
  allocation_count integer;
  distinct_batch_count integer;
  position_index integer := 0;
begin
  if actor is null or not public.current_profile_is_active() then
    raise exception using errcode = '42501', message = 'Active warehouse account required';
  end if;
  if jsonb_typeof(payload_receipt) is distinct from 'object'
     or receipt_id is null or receipt_id = '' or receipt_code is null or receipt_code = ''
     or customer_id is null or customer_id = '' or rice_id is null or rice_id = ''
     or jsonb_typeof(allocations) is distinct from 'array' then
    raise exception using errcode = '22023', message = 'Export receipt is invalid';
  end if;
  if amount <= 0 or unit_price < 0 or total < 0
     or abs(total - amount * unit_price) > 0.01 then
    raise exception using errcode = '22023', message = 'Export quantity or amount is invalid';
  end if;

  select count(*)::integer, count(distinct item ->> 'batchId')::integer,
    coalesce(sum((item ->> 'allocatedQuantity')::numeric), 0)
  into allocation_count, distinct_batch_count, allocated
  from jsonb_array_elements(allocations) as element(item);
  if allocation_count < 1 or allocation_count > 200
     or allocation_count <> distinct_batch_count or abs(allocated - amount) > 0.0001 then
    raise exception using errcode = '22023', message = 'Batch allocations are invalid';
  end if;

  perform batch.id from public.batches as batch
  where batch.id in (select element.item ->> 'batchId' from jsonb_array_elements(allocations) as element(item))
  order by batch.id for update;
  select * into customer from public.customers where id = customer_id and is_active for share;
  if not found then raise exception using errcode = '23503', message = 'Customer is missing or inactive'; end if;
  select * into rice from public.rice_products where id = rice_id and is_active for share;
  if not found then raise exception using errcode = '23503', message = 'Rice product is missing or inactive'; end if;
  if exists (select 1 from public.export_receipts where id = receipt_id or code = receipt_code) then
    raise exception using errcode = '23505', message = 'Export receipt already exists';
  end if;

  insert into public.export_receipts (
    id, code, customer_id, customer_name, date, rice_id, rice_name, quantity,
    selling_price, total_amount, note, status, performed_by
  ) values (
    receipt_id, receipt_code, customer_id, customer.name, receipt_date,
    rice_id, rice.name, amount, unit_price,
    total, coalesce(payload_receipt ->> 'note', ''), 'confirmed', actor::text
  );

  for allocation in
    select element.item from jsonb_array_elements(allocations) with ordinality as element(item, ordinality)
    order by element.ordinality
  loop
    allocated := (allocation ->> 'allocatedQuantity')::numeric;
    if allocated <= 0 then raise exception using errcode = '22023', message = 'Allocation must be positive'; end if;
    select * into batch_row from public.batches where id = allocation ->> 'batchId' for update;
    if not found or batch_row.rice_id <> rice_id
       or batch_row.status not in ('available', 'lowStock')
       or batch_row.expiry_date < (pg_catalog.now() at time zone 'Asia/Ho_Chi_Minh')::date then
      raise exception using errcode = '23514', message = 'Batch is unavailable for export';
    end if;
    if allocated > batch_row.quantity + 0.0001 then
      raise exception using errcode = '23514', message = 'Insufficient batch quantity';
    end if;
    remaining := greatest(0, batch_row.quantity - allocated);
    insert into public.export_receipt_allocations (
      receipt_id, position, batch_id, batch_code, allocated_quantity,
      batch_initial_quantity, batch_remaining_quantity, expiry_date
    ) values (
      receipt_id, position_index, batch_row.id, batch_row.code, allocated,
      batch_row.quantity, remaining, batch_row.expiry_date
    );
    update public.batches
    set quantity = remaining, status = case when remaining <= 100 then 'lowStock' else 'available' end
    where id = batch_row.id;
    insert into public.stock_movements (
      id, type, batch_id, rice_id, quantity_delta, quantity_before,
      quantity_after, reference_type, reference_id, performed_by,
      note
    ) values (
      'mov_exp_' || receipt_id || '_' || batch_row.id, 'export', batch_row.id,
      rice_id, -allocated, batch_row.quantity, remaining, 'export_receipt',
      receipt_id, actor::text, coalesce(payload_receipt ->> 'note', '')
    );
    position_index := position_index + 1;
  end loop;
end;
$$;

create or replace function public.confirm_damage_report(payload_report jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  report_id text := btrim(payload_report ->> 'id');
  report_code text := btrim(payload_report ->> 'code');
  batch_row public.batches%rowtype;
  amount numeric(18, 4) := (payload_report ->> 'quantity')::numeric;
  reason_value text := payload_report ->> 'reason';
  note_value text := coalesce(payload_report ->> 'note', '');
  status_value text := payload_report ->> 'status';
  before_quantity numeric(18, 4);
  after_quantity numeric(18, 4);
begin
  if actor is null or not public.current_profile_is_active() then
    raise exception using errcode = '42501', message = 'Active warehouse account required';
  end if;
  if jsonb_typeof(payload_report) is distinct from 'object'
     or report_id is null or report_id = '' or report_code is null or report_code = ''
     or amount <= 0 or reason_value not in ('baoRach', 'baoUot', 'moc', 'conTrung', 'haoHut', 'khac')
     or status_value not in ('confirmed', 'pending', 'rejected') then
    raise exception using errcode = '22023', message = 'Damage report is invalid';
  end if;
  if status_value <> 'confirmed' then
    raise exception using errcode = '23514', message = 'Only confirmed damage reports can change stock';
  end if;
  select * into batch_row from public.batches where id = payload_report ->> 'batchId' for update;
  if not found or batch_row.rice_id <> payload_report ->> 'riceId'
     or amount > batch_row.quantity + 0.0001 then
    raise exception using errcode = '23514', message = 'Batch mismatch or insufficient quantity';
  end if;
  if exists (select 1 from public.damage_reports where id = report_id or code = report_code) then
    raise exception using errcode = '23505', message = 'Damage report already exists';
  end if;

  before_quantity := batch_row.quantity;
  after_quantity := greatest(0, before_quantity - amount);
  update public.batches set quantity = after_quantity where id = batch_row.id;
  insert into public.damage_reports (
    id, code, batch_id, batch_code, rice_id, rice_name, quantity, reason,
    note, image_path, created_by, reported_by, reported_at, created_at, status
  ) values (
    report_id, report_code, batch_row.id, batch_row.code, batch_row.rice_id,
    batch_row.rice_name, amount, reason_value, nullif(note_value, ''),
    nullif(payload_report ->> 'imagePath', ''), actor::text, actor::text,
    coalesce((payload_report ->> 'createdAt')::timestamptz, pg_catalog.now()),
    coalesce((payload_report ->> 'createdAt')::timestamptz, pg_catalog.now()), 'confirmed'
  );
  insert into public.stock_movements (
    id, type, batch_id, rice_id, quantity_delta, quantity_before,
    quantity_after, reference_type, reference_id, performed_by, note
  ) values (
    'mov_dmg_' || report_id || '_' || batch_row.id, 'damage', batch_row.id,
    batch_row.rice_id, -amount, before_quantity, after_quantity,
    'damage_report', report_id, actor::text, note_value
  );
end;
$$;

create or replace function public.complete_inventory_check(payload_session jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  check_id text := btrim(payload_session ->> 'id');
  check_code text := btrim(payload_session ->> 'code');
  items jsonb := payload_session -> 'items';
  item jsonb;
  batch_row public.batches%rowtype;
  expected numeric(18, 4);
  actual numeric(18, 4);
  difference numeric(18, 4);
  item_count integer;
  distinct_batch_count integer;
  difference_total numeric(18, 4) := 0;
begin
  if actor is null or not public.current_profile_is_active() then
    raise exception using errcode = '42501', message = 'Active warehouse account required';
  end if;
  if jsonb_typeof(payload_session) is distinct from 'object'
     or check_id is null or check_id = '' or check_code is null or check_code = ''
     or jsonb_typeof(items) is distinct from 'array' then
    raise exception using errcode = '22023', message = 'Inventory check is invalid';
  end if;
  select count(*)::integer, count(distinct value ->> 'batchId')::integer
  into item_count, distinct_batch_count
  from jsonb_array_elements(items);
  if item_count < 1 or item_count > 200 or item_count <> distinct_batch_count then
    raise exception using errcode = '22023', message = 'Inventory check items are invalid';
  end if;
  perform batch.id from public.batches as batch
  where batch.id in (select entry.value ->> 'batchId' from jsonb_array_elements(items) as entry(value))
  order by batch.id for update;
  if exists (select 1 from public.inventory_checks where id = check_id or code = check_code) then
    raise exception using errcode = '23505', message = 'Inventory check already exists';
  end if;

  insert into public.inventory_checks (
    id, code, created_at, completed_at, status, total_items,
    total_difference, note, created_by, performed_by
  ) values (
    check_id, check_code, coalesce((payload_session ->> 'createdAt')::timestamptz, pg_catalog.now()),
    pg_catalog.now(), 'completed', item_count, 0,
    nullif(payload_session ->> 'note', ''), actor::text, actor::text
  );

  for item in select value from jsonb_array_elements(items)
  loop
    expected := (item ->> 'expectedQuantity')::numeric;
    actual := (item ->> 'actualQuantity')::numeric;
    difference := actual - expected;
    if expected < 0 or actual < 0
       or item ->> 'reason' not in ('none', 'haoHut', 'baoRach', 'saiDuLieu', 'matHang', 'khac') then
      raise exception using errcode = '22023', message = 'Inventory item values are invalid';
    end if;
    select * into batch_row from public.batches where id = item ->> 'batchId' for update;
    if not found or abs(batch_row.quantity - expected) > 0.001 then
      raise exception using errcode = '40001', message = 'Batch stock changed after counting';
    end if;
    insert into public.inventory_check_items (
      check_id, batch_id, batch_code, rice_name, expected_quantity,
      actual_quantity, difference, reason, note
    ) values (
      check_id, batch_row.id, batch_row.code, batch_row.rice_name, expected,
      actual, difference, item ->> 'reason', nullif(item ->> 'note', '')
    );
    if abs(difference) > 0.001 then
      update public.batches set quantity = actual where id = batch_row.id;
      insert into public.stock_movements (
        id, type, batch_id, rice_id, quantity_delta, quantity_before,
        quantity_after, reference_type, reference_id, performed_by, note
      ) values (
        'mov_chk_' || check_id || '_' || batch_row.id, 'inventoryCheck',
        batch_row.id, batch_row.rice_id, difference, expected, actual,
        'inventory_check', check_id, actor::text, coalesce(item ->> 'note', '')
      );
    end if;
    difference_total := difference_total + difference;
  end loop;

  update public.inventory_checks set total_difference = difference_total where id = check_id;
end;
$$;

revoke all on function public.confirm_import_receipt(jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.confirm_export_receipt(jsonb) from public, anon, authenticated;
revoke all on function public.confirm_damage_report(jsonb) from public, anon, authenticated;
revoke all on function public.complete_inventory_check(jsonb) from public, anon, authenticated;
grant execute on function public.confirm_import_receipt(jsonb, jsonb) to authenticated;
grant execute on function public.confirm_export_receipt(jsonb) to authenticated;
grant execute on function public.confirm_damage_report(jsonb) to authenticated;
grant execute on function public.complete_inventory_check(jsonb) to authenticated;
