-- Access contract: active warehouse users can
-- read operational data, only admins manage catalog/profile access, and all
-- inventory mutations remain server-side transactions.

create or replace function public.current_profile_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select profile.is_active
    from public.profiles as profile
    where profile.id = (select auth.uid())
  ), false);
$$;

create or replace function public.current_profile_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select profile.is_active and profile.role = 'admin'
    from public.profiles as profile
    where profile.id = (select auth.uid())
  ), false);
$$;

revoke all on function public.current_profile_is_active() from public, anon, authenticated;
revoke all on function public.current_profile_is_admin() from public, anon, authenticated;
grant execute on function public.current_profile_is_active() to authenticated;
grant execute on function public.current_profile_is_admin() to authenticated;

create or replace function public.admin_update_profile_access(
  target_user_id uuid,
  target_role text,
  target_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_admin_count integer;
begin
  if not public.current_profile_is_admin() then
    raise exception using errcode = '42501', message = 'Admin role required';
  end if;
  if target_role not in ('admin', 'staff') then
    raise exception using errcode = '22023', message = 'Invalid profile role';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;

  if exists (
    select 1 from public.profiles
    where id = target_user_id and role = 'admin' and is_active
  ) and (target_role <> 'admin' or not target_is_active) then
    select count(*)::integer into active_admin_count
    from public.profiles where role = 'admin' and is_active;
    if active_admin_count <= 1 then
      raise exception using errcode = '23514', message = 'At least one active admin must remain';
    end if;
  end if;

  update public.profiles
  set role = target_role, is_active = target_is_active, updated_at = pg_catalog.now()
  where id = target_user_id;
end;
$$;

revoke all on function public.admin_update_profile_access(uuid, text, boolean)
  from public, anon, authenticated;
grant execute on function public.admin_update_profile_access(uuid, text, boolean)
  to authenticated;

-- Authenticated users have table-level read grants, filtered by RLS.
grant select on public.profiles,
  public.rice_characteristics,
  public.rice_products,
  public.rice_product_characteristics,
  public.suppliers,
  public.customers,
  public.warehouse_locations,
  public.batches,
  public.batch_codes,
  public.import_receipts,
  public.export_receipts,
  public.export_receipt_allocations,
  public.damage_reports,
  public.inventory_checks,
  public.inventory_check_items,
  public.inventory_snapshots,
  public.stock_movements,
  public.migration_runs,
  public.warehouse_locations_with_count
to authenticated;

-- Staff can update only their display name. Access fields are changed through
-- the admin RPC so clients can never grant themselves active/admin access.
grant update (display_name) on public.profiles to authenticated;

-- Admin-managed reference data.
grant insert, update, delete on public.rice_characteristics,
  public.rice_products,
  public.rice_product_characteristics,
  public.suppliers,
  public.customers,
  public.warehouse_locations
to authenticated;

grant usage, select on all sequences in schema public to authenticated;

-- The only direct batch mutation permitted is a location move. Stock fields
-- and batch identity are exclusively modified inside trusted RPCs.
grant update (warehouse_location_id, location_name) on public.batches to authenticated;

-- Preserve the existing access behavior allowing active staff/admin to manage
-- snapshots; all ledger and receipt writes remain immutable to clients.
grant insert, update, delete on public.inventory_snapshots to authenticated;

create policy profiles_read_self_or_admin on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or (select public.current_profile_is_admin()));
create policy profiles_update_self_name on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) and (select public.current_profile_is_active()))
  with check (id = (select auth.uid()) and (select public.current_profile_is_active()));

create policy rice_characteristics_read_active on public.rice_characteristics
  for select to authenticated using ((select public.current_profile_is_active()));
create policy rice_characteristics_admin_write on public.rice_characteristics
  for all to authenticated using ((select public.current_profile_is_admin()))
  with check ((select public.current_profile_is_admin()));

create policy rice_products_read_active on public.rice_products
  for select to authenticated using ((select public.current_profile_is_active()));
create policy rice_products_admin_write on public.rice_products
  for all to authenticated using ((select public.current_profile_is_admin()))
  with check ((select public.current_profile_is_admin()));

create policy rice_product_characteristics_read_active on public.rice_product_characteristics
  for select to authenticated using ((select public.current_profile_is_active()));
create policy rice_product_characteristics_admin_write on public.rice_product_characteristics
  for all to authenticated using ((select public.current_profile_is_admin()))
  with check ((select public.current_profile_is_admin()));

create policy suppliers_read_active on public.suppliers
  for select to authenticated using ((select public.current_profile_is_active()));
create policy suppliers_admin_write on public.suppliers
  for all to authenticated using ((select public.current_profile_is_admin()))
  with check ((select public.current_profile_is_admin()));

create policy customers_read_active on public.customers
  for select to authenticated using ((select public.current_profile_is_active()));
create policy customers_admin_write on public.customers
  for all to authenticated using ((select public.current_profile_is_admin()))
  with check ((select public.current_profile_is_admin()));

create policy warehouse_locations_read_active on public.warehouse_locations
  for select to authenticated using ((select public.current_profile_is_active()));
create policy warehouse_locations_admin_write on public.warehouse_locations
  for all to authenticated using ((select public.current_profile_is_admin()))
  with check ((select public.current_profile_is_admin()));

create policy batches_read_active on public.batches
  for select to authenticated using ((select public.current_profile_is_active()));
create policy batches_move_location on public.batches
  for update to authenticated
  using ((select public.current_profile_is_active()))
  with check (
    (select public.current_profile_is_active())
    and (warehouse_location_id is null or exists (
      select 1 from public.warehouse_locations as location
      where location.id = warehouse_location_id and location.is_active
    ))
  );

create policy batch_codes_read_active on public.batch_codes
  for select to authenticated using ((select public.current_profile_is_active()));
create policy import_receipts_read_active on public.import_receipts
  for select to authenticated using ((select public.current_profile_is_active()));
create policy export_receipts_read_active on public.export_receipts
  for select to authenticated using ((select public.current_profile_is_active()));
create policy export_allocations_read_active on public.export_receipt_allocations
  for select to authenticated using ((select public.current_profile_is_active()));
create policy damage_reports_read_active on public.damage_reports
  for select to authenticated using ((select public.current_profile_is_active()));
create policy inventory_checks_read_active on public.inventory_checks
  for select to authenticated using ((select public.current_profile_is_active()));
create policy inventory_check_items_read_active on public.inventory_check_items
  for select to authenticated using ((select public.current_profile_is_active()));
create policy inventory_snapshots_manage_active on public.inventory_snapshots
  for all to authenticated using ((select public.current_profile_is_active()))
  with check ((select public.current_profile_is_active()));
create policy stock_movements_read_active on public.stock_movements
  for select to authenticated using ((select public.current_profile_is_active()));
create policy migration_runs_read_admin on public.migration_runs
  for select to authenticated using ((select public.current_profile_is_admin()));

-- Supabase Realtime publication is required by repository stream adapters.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'rice_characteristics', 'rice_products',
    'rice_product_characteristics', 'suppliers', 'customers',
    'warehouse_locations', 'batches', 'batch_codes', 'import_receipts',
    'export_receipts', 'export_receipt_allocations', 'damage_reports',
    'inventory_checks', 'inventory_check_items', 'inventory_snapshots',
    'stock_movements', 'migration_runs'
  ] loop
    if not exists (
      select 1 from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = table_name
    ) then
      execute pg_catalog.format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;
