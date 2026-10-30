-- One-time, idempotent import of the owner-approved TMP opening stock.
-- Source: functions/fixtures/temporary_opening_stock_2026-10-29.json
-- Run only against the linked hosted project after reviewing the target ref.
begin;

do $migration$
declare
  v_run_id constant text := 'tmp-opening-stock-2026-10-29';
  v_manifest_hash constant text := '73979be94d4a577ca0d23508318b036c728abeb598287a584bf6754169b45530';
  v_count integer;
begin
  if exists (select 1 from public.migration_runs where id = v_run_id) then
    if not exists (
      select 1 from public.migration_runs
      where id = v_run_id
        and manifest_hash = v_manifest_hash
        and status = 'completed'
        and total_records = 12
        and inserted_records = 12
        and skipped_records = 0
    ) then
      raise exception 'TMP migration run exists but does not match the approved fixture';
    end if;

    select count(*) into v_count from public.rice_products
    where source_migration_run = v_run_id
      and id in ('tmp-rice-st25-20261029', 'tmp-rice-jasmine-20261029', 'tmp-rice-nanghuong-20261029');
    if v_count <> 3 then raise exception 'Existing TMP product set is incomplete'; end if;

    select count(*) into v_count from public.batches
    where source_migration_run = v_run_id
      and id in ('tmp-seed-batch-st25-20261029', 'tmp-seed-batch-jasmine-20261029', 'tmp-seed-batch-nanghuong-20261029');
    if v_count <> 3 then raise exception 'Existing TMP batch set is incomplete'; end if;

    select count(*) into v_count from public.stock_movements
    where source_migration_run = v_run_id
      and reference_id = v_run_id
      and type = 'migration';
    if v_count <> 3 then raise exception 'Existing TMP opening movement set is incomplete'; end if;

    select count(*) into v_count from public.batch_codes
    where batch_id in ('tmp-seed-batch-st25-20261029', 'tmp-seed-batch-jasmine-20261029', 'tmp-seed-batch-nanghuong-20261029');
    if v_count <> 3 then raise exception 'Existing TMP batch-code set is incomplete'; end if;

    raise notice 'Approved TMP fixture is already present and complete; no changes made.';
    return;
  end if;

  if exists (
    select 1 from public.rice_products
    where id in ('tmp-rice-st25-20261029', 'tmp-rice-jasmine-20261029', 'tmp-rice-nanghuong-20261029')
       or lower(btrim(code)) in ('tmp-rice-st25-20261029', 'tmp-rice-jas-20261029', 'tmp-rice-nh-20261029')
  ) or exists (
    select 1 from public.batches
    where id in ('tmp-seed-batch-st25-20261029', 'tmp-seed-batch-jasmine-20261029', 'tmp-seed-batch-nanghuong-20261029')
       or lower(btrim(code)) in ('tmp-20261029-st25-01', 'tmp-20261029-jas-01', 'tmp-20261029-nh-01')
  ) or exists (
    select 1 from public.batch_codes
    where code_key in ('tmp-20261029-st25-01', 'tmp-20261029-jas-01', 'tmp-20261029-nh-01')
  ) or exists (
    select 1 from public.stock_movements
    where id in (
      'mov_legacy_tmp-seed-batch-st25-20261029',
      'mov_legacy_tmp-seed-batch-jasmine-20261029',
      'mov_legacy_tmp-seed-batch-nanghuong-20261029'
    )
  ) then
    raise exception 'A TMP fixture ID or code already exists without its migration marker; refusing to overwrite';
  end if;

  insert into public.migration_runs (
    id, manifest_hash, status, total_records, inserted_records, skipped_records, metadata
  ) values (
    v_run_id,
    v_manifest_hash,
    'inProgress',
    12,
    0,
    0,
    jsonb_build_object(
      'fixture', 'temporary_opening_stock_2026-10-29.json',
      'temporary', true,
      'snapshot_date', '2026-10-29',
      'total_quantity_kg', 1200,
      'cleanup_marker', v_run_id
    )
  );

  insert into public.rice_products (
    id, code, name, category, unit, purchase_price, selling_price,
    minimum_stock, description, is_active, source_migration_run, created_at, updated_at
  ) values
    ('tmp-rice-st25-20261029', 'TMP-RICE-ST25-20261029', 'Gạo ST25', 'Gạo thơm đặc sản', 'kg', 25000, 32000, 100,
      'Dữ liệu khởi tạo tạm thời do chủ dự án yêu cầu.', true, v_run_id, '2026-10-29T00:00:00Z', '2026-10-29T00:00:00Z'),
    ('tmp-rice-jasmine-20261029', 'TMP-RICE-JAS-20261029', 'Gạo Jasmine', 'Gạo thơm', 'kg', 18000, 24000, 100,
      'Dữ liệu khởi tạo tạm thời do chủ dự án yêu cầu.', true, v_run_id, '2026-10-29T00:00:00Z', '2026-10-29T00:00:00Z'),
    ('tmp-rice-nanghuong-20261029', 'TMP-RICE-NH-20261029', 'Gạo Nàng Hương', 'Gạo thơm', 'kg', 20000, 27000, 100,
      'Dữ liệu khởi tạo tạm thời do chủ dự án yêu cầu.', true, v_run_id, '2026-10-29T00:00:00Z', '2026-10-29T00:00:00Z');

  insert into public.batches (
    id, code, rice_id, rice_name, quantity, import_date, manufacture_date,
    expiry_date, status, source_migration_run
  ) values
    ('tmp-seed-batch-st25-20261029', 'TMP-20261029-ST25-01', 'tmp-rice-st25-20261029', 'Gạo ST25', 500, '2026-10-29', '2026-10-01', '2027-09-30', 'available', v_run_id),
    ('tmp-seed-batch-jasmine-20261029', 'TMP-20261029-JAS-01', 'tmp-rice-jasmine-20261029', 'Gạo Jasmine', 400, '2026-10-29', '2026-10-01', '2027-09-30', 'available', v_run_id),
    ('tmp-seed-batch-nanghuong-20261029', 'TMP-20261029-NH-01', 'tmp-rice-nanghuong-20261029', 'Gạo Nàng Hương', 300, '2026-10-29', '2026-10-01', '2027-09-30', 'available', v_run_id);

  insert into public.batch_codes (code_key, code, batch_id)
  values
    ('tmp-20261029-st25-01', 'TMP-20261029-ST25-01', 'tmp-seed-batch-st25-20261029'),
    ('tmp-20261029-jas-01', 'TMP-20261029-JAS-01', 'tmp-seed-batch-jasmine-20261029'),
    ('tmp-20261029-nh-01', 'TMP-20261029-NH-01', 'tmp-seed-batch-nanghuong-20261029');

  insert into public.stock_movements (
    id, type, batch_id, rice_id, quantity_delta, quantity_before, quantity_after,
    reference_type, reference_id, created_at, note, source_migration_run
  ) values
    ('mov_legacy_tmp-seed-batch-st25-20261029', 'migration', 'tmp-seed-batch-st25-20261029', 'tmp-rice-st25-20261029', 500, 0, 500,
      'migration', v_run_id, '2026-10-29T00:00:00Z', 'Tồn đầu kỳ tạm thời; xóa riêng theo source_migration_run trước phát hành.', v_run_id),
    ('mov_legacy_tmp-seed-batch-jasmine-20261029', 'migration', 'tmp-seed-batch-jasmine-20261029', 'tmp-rice-jasmine-20261029', 400, 0, 400,
      'migration', v_run_id, '2026-10-29T00:00:00Z', 'Tồn đầu kỳ tạm thời; xóa riêng theo source_migration_run trước phát hành.', v_run_id),
    ('mov_legacy_tmp-seed-batch-nanghuong-20261029', 'migration', 'tmp-seed-batch-nanghuong-20261029', 'tmp-rice-nanghuong-20261029', 300, 0, 300,
      'migration', v_run_id, '2026-10-29T00:00:00Z', 'Tồn đầu kỳ tạm thời; xóa riêng theo source_migration_run trước phát hành.', v_run_id);

  update public.migration_runs
  set status = 'completed', inserted_records = 12, completed_at = now()
  where id = v_run_id;
end;
$migration$;

commit;
