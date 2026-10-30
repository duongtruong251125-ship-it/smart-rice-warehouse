-- Explicitly remove only the TMP fixture associated with its migration run.
-- Do not run until the owner confirms the fixture should be retired.
begin;

do $cleanup$
declare
  v_run_id constant text := 'tmp-opening-stock-2026-10-29';
  v_manifest_hash constant text := '73979be94d4a577ca0d23508318b036c728abeb598287a584bf6754169b45530';
  v_count integer;
begin
  if not exists (
    select 1 from public.migration_runs
    where id = v_run_id and manifest_hash = v_manifest_hash and status = 'completed'
  ) then
    raise exception 'Expected completed TMP migration run is missing or has changed';
  end if;

  select count(*) into v_count from public.batches
  where source_migration_run = v_run_id
    and id in ('tmp-seed-batch-st25-20261029', 'tmp-seed-batch-jasmine-20261029', 'tmp-seed-batch-nanghuong-20261029');
  if v_count <> 3 then raise exception 'Expected exactly 3 TMP batches'; end if;

  select count(*) into v_count from public.rice_products
  where source_migration_run = v_run_id
    and id in ('tmp-rice-st25-20261029', 'tmp-rice-jasmine-20261029', 'tmp-rice-nanghuong-20261029');
  if v_count <> 3 then raise exception 'Expected exactly 3 TMP rice products'; end if;

  if exists (
    select 1 from public.export_receipt_allocations
    where batch_id in (select id from public.batches where source_migration_run = v_run_id)
  ) or exists (
    select 1 from public.inventory_check_items
    where batch_id in (select id from public.batches where source_migration_run = v_run_id)
  ) or exists (
    select 1 from public.damage_reports
    where batch_id in (select id from public.batches where source_migration_run = v_run_id)
  ) or exists (
    select 1 from public.import_receipts
    where lower(btrim(batch_code)) in ('tmp-20261029-st25-01', 'tmp-20261029-jas-01', 'tmp-20261029-nh-01')
  ) or exists (
    select 1 from public.stock_movements
    where batch_id in (select id from public.batches where source_migration_run = v_run_id)
      and source_migration_run is distinct from v_run_id
  ) then
    raise exception 'TMP records are now referenced by non-TMP business history; refusing cleanup';
  end if;

  delete from public.stock_movements
  where source_migration_run = v_run_id
    and batch_id in (select id from public.batches where source_migration_run = v_run_id);

  delete from public.batch_codes
  where batch_id in (select id from public.batches where source_migration_run = v_run_id);

  delete from public.batches where source_migration_run = v_run_id
    and id in ('tmp-seed-batch-st25-20261029', 'tmp-seed-batch-jasmine-20261029', 'tmp-seed-batch-nanghuong-20261029');

  delete from public.rice_product_characteristics
  where rice_id in (select id from public.rice_products where source_migration_run = v_run_id);

  delete from public.rice_products where source_migration_run = v_run_id
    and id in ('tmp-rice-st25-20261029', 'tmp-rice-jasmine-20261029', 'tmp-rice-nanghuong-20261029');

  delete from public.migration_runs
  where id = v_run_id and manifest_hash = v_manifest_hash;
end;
$cleanup$;

commit;
