-- Initial relational model for Smart Rice Warehouse.
-- RLS is enabled on every application table. Client grants and policies are
-- intentionally added in a later migration after the access contract tests.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  firebase_uid text unique,
  email text not null default '',
  display_name text not null default 'Nhân viên',
  role text not null default 'staff' check (role in ('admin', 'staff')),
  is_active boolean not null default false,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(btrim(display_name)) between 1 and 100)
);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, role, is_active)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'Nhân viên'),
    'staff',
    false
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

create table public.rice_characteristics (
  id text primary key,
  name text not null check (length(btrim(name)) > 0),
  description text not null default '',
  color_value bigint not null default 0,
  is_default boolean not null default false,
  source_migration_run text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rice_products (
  id text primary key,
  code text not null check (length(btrim(code)) > 0),
  name text not null check (length(btrim(name)) > 0),
  category text not null default '',
  unit text not null default 'kg',
  purchase_price numeric(18, 2) not null default 0 check (purchase_price >= 0),
  selling_price numeric(18, 2) not null default 0 check (selling_price >= 0),
  minimum_stock numeric(18, 4) not null default 0 check (minimum_stock >= 0),
  description text not null default '',
  is_active boolean not null default true,
  image_path text,
  source_migration_run text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index rice_products_code_ci_uq
  on public.rice_products (lower(btrim(code)));

create table public.rice_product_characteristics (
  rice_id text not null references public.rice_products (id) on delete cascade,
  characteristic_id text not null references public.rice_characteristics (id) on delete restrict,
  primary key (rice_id, characteristic_id)
);

create table public.suppliers (
  id text primary key,
  name text not null check (length(btrim(name)) > 0),
  phone text not null default '',
  email text not null default '',
  address text not null default '',
  tax_code text not null default '',
  note text not null default '',
  is_active boolean not null default true,
  source_migration_run text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id text primary key,
  name text not null check (length(btrim(name)) > 0),
  phone text not null default '',
  address text not null default '',
  customer_type text not null default 'retail'
    check (customer_type in ('retail', 'agent', 'business')),
  email text not null default '',
  note text not null default '',
  is_active boolean not null default true,
  source_migration_run text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.warehouse_locations (
  id text primary key,
  zone text not null,
  rack text not null,
  shelf text not null,
  code text not null check (length(btrim(code)) > 0),
  capacity numeric(18, 4) not null check (capacity > 0),
  is_active boolean not null default true,
  description text,
  source_migration_run text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index warehouse_locations_code_ci_uq
  on public.warehouse_locations (lower(btrim(code)));

create table public.batches (
  id text primary key,
  code text not null check (length(btrim(code)) > 0),
  rice_id text not null references public.rice_products (id) on delete restrict,
  rice_name text not null,
  quantity numeric(18, 4) not null check (quantity >= 0),
  import_date date not null,
  manufacture_date date not null,
  expiry_date date not null,
  status text not null check (status in ('available', 'lowStock', 'expired', 'qualityHold')),
  supplier_id text references public.suppliers (id) on delete set null,
  supplier_name text,
  warehouse_location_id text references public.warehouse_locations (id) on delete set null,
  location_name text,
  source_migration_run text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (manufacture_date <= expiry_date)
);

create unique index batches_code_ci_uq on public.batches (lower(btrim(code)));
create index batches_rice_id_idx on public.batches (rice_id);
create index batches_location_id_idx on public.batches (warehouse_location_id);
create index batches_expiry_status_idx on public.batches (expiry_date, status);

create table public.batch_codes (
  code_key text primary key,
  code text not null,
  batch_id text not null unique references public.batches (id) on delete restrict,
  created_at timestamptz not null default now(),
  check (code_key = lower(btrim(code)))
);

create table public.import_receipts (
  id text primary key,
  code text not null unique check (length(btrim(code)) > 0),
  supplier_id text not null references public.suppliers (id) on delete restrict,
  supplier_name text not null,
  date date not null,
  rice_id text not null references public.rice_products (id) on delete restrict,
  rice_name text not null,
  quantity numeric(18, 4) not null check (quantity > 0),
  purchase_price numeric(18, 2) not null check (purchase_price >= 0),
  total_amount numeric(18, 2) not null check (total_amount >= 0),
  batch_code text not null,
  manufacture_date date not null,
  expiry_date date not null,
  status text not null default 'confirmed' check (status = 'confirmed'),
  performed_by text,
  source_migration_run text,
  created_at timestamptz not null default now(),
  check (manufacture_date <= expiry_date),
  check (abs(total_amount - quantity * purchase_price) <= 0.01)
);

create index import_receipts_date_idx on public.import_receipts (date desc);
create index import_receipts_rice_id_idx on public.import_receipts (rice_id);

create table public.export_receipts (
  id text primary key,
  code text not null unique check (length(btrim(code)) > 0),
  customer_id text not null references public.customers (id) on delete restrict,
  customer_name text not null,
  date date not null,
  rice_id text not null references public.rice_products (id) on delete restrict,
  rice_name text not null,
  quantity numeric(18, 4) not null check (quantity > 0),
  selling_price numeric(18, 2) not null check (selling_price >= 0),
  total_amount numeric(18, 2) not null check (total_amount >= 0),
  note text not null default '',
  status text not null default 'confirmed' check (status = 'confirmed'),
  performed_by text,
  source_migration_run text,
  created_at timestamptz not null default now(),
  check (abs(total_amount - quantity * selling_price) <= 0.01)
);

create index export_receipts_date_idx on public.export_receipts (date desc);
create index export_receipts_rice_id_idx on public.export_receipts (rice_id);

create table public.export_receipt_allocations (
  receipt_id text not null references public.export_receipts (id) on delete restrict,
  position smallint not null check (position >= 0),
  batch_id text not null references public.batches (id) on delete restrict,
  batch_code text not null,
  allocated_quantity numeric(18, 4) not null check (allocated_quantity > 0),
  batch_initial_quantity numeric(18, 4) not null check (batch_initial_quantity >= 0),
  batch_remaining_quantity numeric(18, 4) not null check (batch_remaining_quantity >= 0),
  expiry_date date not null,
  primary key (receipt_id, position)
);

create index export_allocations_batch_id_idx
  on public.export_receipt_allocations (batch_id);

create table public.damage_reports (
  id text primary key,
  code text not null unique check (length(btrim(code)) > 0),
  batch_id text not null references public.batches (id) on delete restrict,
  batch_code text not null,
  rice_id text not null references public.rice_products (id) on delete restrict,
  rice_name text not null,
  quantity numeric(18, 4) not null check (quantity > 0),
  reason text not null check (reason in ('baoRach', 'baoUot', 'moc', 'conTrung', 'haoHut', 'khac')),
  note text,
  image_path text,
  created_by text,
  reported_by text,
  reported_at timestamptz,
  created_at timestamptz not null default now(),
  status text not null check (status in ('pending', 'confirmed', 'rejected')),
  source_migration_run text
);

create index damage_reports_created_at_idx on public.damage_reports (created_at desc);
create index damage_reports_batch_id_idx on public.damage_reports (batch_id);

create table public.inventory_checks (
  id text primary key,
  code text not null unique check (length(btrim(code)) > 0),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null check (status in ('inProgress', 'completed', 'cancelled')),
  total_items integer not null default 0 check (total_items >= 0),
  total_difference numeric(18, 4) not null default 0,
  note text,
  created_by text,
  performed_by text,
  source_migration_run text
);

create table public.inventory_check_items (
  check_id text not null references public.inventory_checks (id) on delete restrict,
  batch_id text not null references public.batches (id) on delete restrict,
  batch_code text not null,
  rice_name text not null,
  expected_quantity numeric(18, 4) not null check (expected_quantity >= 0),
  actual_quantity numeric(18, 4) not null check (actual_quantity >= 0),
  difference numeric(18, 4) not null,
  reason text not null check (reason in ('none', 'haoHut', 'baoRach', 'saiDuLieu', 'matHang', 'khac')),
  note text,
  primary key (check_id, batch_id),
  check (difference = actual_quantity - expected_quantity)
);

create index inventory_checks_created_at_idx on public.inventory_checks (created_at desc);

create table public.inventory_snapshots (
  id bigint generated by default as identity primary key,
  date date not null unique,
  total_quantity numeric(18, 4) not null check (total_quantity >= 0),
  total_value numeric(18, 2) not null check (total_value >= 0),
  note text not null default '',
  source_migration_run text
);

create table public.stock_movements (
  id text primary key,
  type text not null check (type in ('import', 'export', 'damage', 'inventoryCheck', 'adjustment', 'migration')),
  batch_id text not null references public.batches (id) on delete restrict,
  rice_id text not null references public.rice_products (id) on delete restrict,
  quantity_delta numeric(18, 4) not null,
  quantity_before numeric(18, 4) not null check (quantity_before >= 0),
  quantity_after numeric(18, 4) not null check (quantity_after >= 0),
  reference_type text not null,
  reference_id text not null,
  performed_by text,
  created_at timestamptz not null default now(),
  note text not null default '',
  source_migration_run text,
  check (quantity_after = quantity_before + quantity_delta)
);

create index stock_movements_batch_created_idx
  on public.stock_movements (batch_id, created_at desc);
create index stock_movements_reference_idx
  on public.stock_movements (reference_type, reference_id);

create table public.migration_runs (
  id text primary key,
  manifest_hash text not null,
  status text not null check (status in ('inProgress', 'completed', 'failed')),
  total_records integer not null check (total_records >= 0),
  inserted_records integer not null default 0 check (inserted_records >= 0),
  skipped_records integer not null default 0 check (skipped_records >= 0),
  performed_by text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

-- Remove any project-level default API grants; the next migration will add
-- only the grants required by the tested policies and RPCs.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

-- The app reads this projection to populate WarehouseLocationModel.currentBatchCount.
create view public.warehouse_locations_with_count
with (security_invoker = true)
as
select
  location.*,
  count(batch.id)::integer as current_batch_count
from public.warehouse_locations as location
left join public.batches as batch
  on batch.warehouse_location_id = location.id
group by location.id;

-- Every application table starts locked. A later migration grants only the
-- operations required by the tested RLS contract and RPCs.
alter table public.profiles enable row level security;
alter table public.rice_characteristics enable row level security;
alter table public.rice_products enable row level security;
alter table public.rice_product_characteristics enable row level security;
alter table public.suppliers enable row level security;
alter table public.customers enable row level security;
alter table public.warehouse_locations enable row level security;
alter table public.batches enable row level security;
alter table public.batch_codes enable row level security;
alter table public.import_receipts enable row level security;
alter table public.export_receipts enable row level security;
alter table public.export_receipt_allocations enable row level security;
alter table public.damage_reports enable row level security;
alter table public.inventory_checks enable row level security;
alter table public.inventory_check_items enable row level security;
alter table public.inventory_snapshots enable row level security;
alter table public.stock_movements enable row level security;
alter table public.migration_runs enable row level security;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger rice_characteristics_set_updated_at before update on public.rice_characteristics
  for each row execute function public.set_updated_at();
create trigger rice_products_set_updated_at before update on public.rice_products
  for each row execute function public.set_updated_at();
create trigger suppliers_set_updated_at before update on public.suppliers
  for each row execute function public.set_updated_at();
create trigger customers_set_updated_at before update on public.customers
  for each row execute function public.set_updated_at();
create trigger warehouse_locations_set_updated_at before update on public.warehouse_locations
  for each row execute function public.set_updated_at();
create trigger batches_set_updated_at before update on public.batches
  for each row execute function public.set_updated_at();
