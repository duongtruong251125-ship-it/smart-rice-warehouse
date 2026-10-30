-- Remove only this explicitly temporary fixture after the owner retires it.
begin;

do $cleanup$
declare
  v_run_id constant text := 'tmp-reference-data-2026-10-30';
  v_manifest_hash constant text := '3bdc20b2c363fd666ff59e4df04309f7590671b1d1237a27b724056f66bb60f3';
  v_count integer;
begin
  if not exists (
    select 1 from public.migration_runs
    where id = v_run_id and manifest_hash = v_manifest_hash
      and status = 'completed' and total_records = 9 and inserted_records = 9
  ) then
    raise exception 'Expected completed temporary reference-data run is missing or has changed';
  end if;

  select count(*) into v_count from public.suppliers
  where source_migration_run = v_run_id
    and id in ('tmp-supplier-rice-north-20261030', 'tmp-supplier-rice-south-20261030', 'tmp-supplier-rice-central-20261030');
  if v_count <> 3 then raise exception 'Expected exactly 3 temporary suppliers'; end if;

  select count(*) into v_count from public.customers
  where source_migration_run = v_run_id
    and id in ('tmp-customer-retail-20261030', 'tmp-customer-agent-20261030', 'tmp-customer-business-20261030');
  if v_count <> 3 then raise exception 'Expected exactly 3 temporary customers'; end if;

  select count(*) into v_count from public.warehouse_locations
  where source_migration_run = v_run_id
    and id in ('tmp-location-a-20261030', 'tmp-location-b-20261030', 'tmp-location-c-20261030');
  if v_count <> 3 then raise exception 'Expected exactly 3 temporary locations'; end if;

  if exists (
    select 1 from public.import_receipts
    where supplier_id in (select id from public.suppliers where source_migration_run = v_run_id)
  ) or exists (
    select 1 from public.batches
    where supplier_id in (select id from public.suppliers where source_migration_run = v_run_id)
  ) or exists (
    select 1 from public.export_receipts
    where customer_id in (select id from public.customers where source_migration_run = v_run_id)
  ) or exists (
    select 1 from public.batches
    where warehouse_location_id in (select id from public.warehouse_locations where source_migration_run = v_run_id)
  ) then
    raise exception 'Temporary reference rows are now used by business data; refusing cleanup';
  end if;

  delete from public.warehouse_locations where source_migration_run = v_run_id
    and id in ('tmp-location-a-20261030', 'tmp-location-b-20261030', 'tmp-location-c-20261030');
  delete from public.customers where source_migration_run = v_run_id
    and id in ('tmp-customer-retail-20261030', 'tmp-customer-agent-20261030', 'tmp-customer-business-20261030');
  delete from public.suppliers where source_migration_run = v_run_id
    and id in ('tmp-supplier-rice-north-20261030', 'tmp-supplier-rice-south-20261030', 'tmp-supplier-rice-central-20261030');
  delete from public.migration_runs where id = v_run_id and manifest_hash = v_manifest_hash;
end;
$cleanup$;

commit;
