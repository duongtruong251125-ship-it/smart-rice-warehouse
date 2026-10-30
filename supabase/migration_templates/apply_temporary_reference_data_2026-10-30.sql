-- Idempotently add clearly labelled sample master data for the hosted app.
-- These rows are fixtures, not verified supplier/customer/location records.
begin;

do $migration$
declare
  v_run_id constant text := 'tmp-reference-data-2026-10-30';
  v_manifest_hash constant text := '3bdc20b2c363fd666ff59e4df04309f7590671b1d1237a27b724056f66bb60f3';
  v_count integer;
begin
  if exists (select 1 from public.migration_runs where id = v_run_id) then
    if not exists (
      select 1 from public.migration_runs
      where id = v_run_id and manifest_hash = v_manifest_hash
        and status = 'completed' and total_records = 9
        and inserted_records = 9 and skipped_records = 0
    ) then
      raise exception 'Temporary reference-data run exists but does not match this fixture';
    end if;

    select count(*) into v_count from public.suppliers
    where source_migration_run = v_run_id
      and id in ('tmp-supplier-rice-north-20261030', 'tmp-supplier-rice-south-20261030', 'tmp-supplier-rice-central-20261030');
    if v_count <> 3 then raise exception 'Temporary supplier fixture is incomplete'; end if;

    select count(*) into v_count from public.customers
    where source_migration_run = v_run_id
      and id in ('tmp-customer-retail-20261030', 'tmp-customer-agent-20261030', 'tmp-customer-business-20261030');
    if v_count <> 3 then raise exception 'Temporary customer fixture is incomplete'; end if;

    select count(*) into v_count from public.warehouse_locations
    where source_migration_run = v_run_id
      and id in ('tmp-location-a-20261030', 'tmp-location-b-20261030', 'tmp-location-c-20261030');
    if v_count <> 3 then raise exception 'Temporary location fixture is incomplete'; end if;

    raise notice 'Temporary reference data is already complete; no changes made.';
    return;
  end if;

  if exists (select 1 from public.suppliers where id in (
       'tmp-supplier-rice-north-20261030', 'tmp-supplier-rice-south-20261030', 'tmp-supplier-rice-central-20261030'
     )) or exists (select 1 from public.customers where id in (
       'tmp-customer-retail-20261030', 'tmp-customer-agent-20261030', 'tmp-customer-business-20261030'
     )) or exists (select 1 from public.warehouse_locations where id in (
       'tmp-location-a-20261030', 'tmp-location-b-20261030', 'tmp-location-c-20261030'
     )) then
    raise exception 'A temporary reference-data ID already exists without its migration marker; refusing to overwrite';
  end if;

  insert into public.migration_runs (
    id, manifest_hash, status, total_records, inserted_records, skipped_records, metadata
  ) values (
    v_run_id, v_manifest_hash, 'inProgress', 9, 0, 0,
    jsonb_build_object(
      'temporary', true,
      'fixture_version', 1,
      'suppliers', 3,
      'customers', 3,
      'warehouse_locations', 3,
      'note', 'Illustrative sample master data only; replace with owner-verified records before release.'
    )
  );

  insert into public.suppliers (
    id, name, phone, email, address, tax_code, note, is_active, source_migration_run
  ) values
    ('tmp-supplier-rice-north-20261030', 'Nhà cung cấp mẫu Miền Bắc', '', '', '', '', 'Dữ liệu mẫu tạm thời; thay bằng thông tin đã xác minh.', true, v_run_id),
    ('tmp-supplier-rice-south-20261030', 'Nhà cung cấp mẫu Miền Nam', '', '', '', '', 'Dữ liệu mẫu tạm thời; thay bằng thông tin đã xác minh.', true, v_run_id),
    ('tmp-supplier-rice-central-20261030', 'Nhà cung cấp mẫu Miền Trung', '', '', '', '', 'Dữ liệu mẫu tạm thời; thay bằng thông tin đã xác minh.', true, v_run_id);

  insert into public.customers (
    id, name, phone, address, customer_type, email, note, is_active, source_migration_run
  ) values
    ('tmp-customer-retail-20261030', 'Khách lẻ mẫu', '', '', 'retail', '', 'Dữ liệu mẫu tạm thời; không phải khách hàng thật.', true, v_run_id),
    ('tmp-customer-agent-20261030', 'Đại lý mẫu', '', '', 'agent', '', 'Dữ liệu mẫu tạm thời; không phải khách hàng thật.', true, v_run_id),
    ('tmp-customer-business-20261030', 'Doanh nghiệp mẫu', '', '', 'business', '', 'Dữ liệu mẫu tạm thời; không phải khách hàng thật.', true, v_run_id);

  insert into public.warehouse_locations (
    id, zone, rack, shelf, code, capacity, is_active, description, source_migration_run
  ) values
    ('tmp-location-a-20261030', 'Khu A mẫu', 'Kệ 1', 'Tầng 1', 'TMP-A-01-01', 1000, true, 'Vị trí minh họa; cần thay bằng sơ đồ và sức chứa đã xác minh.', v_run_id),
    ('tmp-location-b-20261030', 'Khu B mẫu', 'Kệ 1', 'Tầng 1', 'TMP-B-01-01', 1000, true, 'Vị trí minh họa; cần thay bằng sơ đồ và sức chứa đã xác minh.', v_run_id),
    ('tmp-location-c-20261030', 'Khu C mẫu', 'Kệ 1', 'Tầng 1', 'TMP-C-01-01', 1000, true, 'Vị trí minh họa; cần thay bằng sơ đồ và sức chứa đã xác minh.', v_run_id);

  update public.migration_runs
  set status = 'completed', inserted_records = 9, completed_at = now()
  where id = v_run_id;
end;
$migration$;

commit;
