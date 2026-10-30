begin;

select plan(12);

select ok(
  (select count(*) = 18
   from pg_catalog.pg_class as relation
   join pg_catalog.pg_namespace as namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relkind = 'r'
     and relation.relname = any (array[
       'profiles', 'rice_characteristics', 'rice_products',
       'rice_product_characteristics', 'suppliers', 'customers',
       'warehouse_locations', 'batches', 'batch_codes', 'import_receipts',
       'export_receipts', 'export_receipt_allocations', 'damage_reports',
       'inventory_checks', 'inventory_check_items', 'inventory_snapshots',
       'stock_movements', 'migration_runs'
     ])),
  'the initial schema contains all 18 expected application tables'
);

select ok(
  (select count(*) = 18 and bool_and(relation.relrowsecurity)
   from pg_catalog.pg_class as relation
   join pg_catalog.pg_namespace as namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'
     and relation.relkind = 'r'
     and relation.relname = any (array[
       'profiles', 'rice_characteristics', 'rice_products',
       'rice_product_characteristics', 'suppliers', 'customers',
       'warehouse_locations', 'batches', 'batch_codes', 'import_receipts',
       'export_receipts', 'export_receipt_allocations', 'damage_reports',
       'inventory_checks', 'inventory_check_items', 'inventory_snapshots',
       'stock_movements', 'migration_runs'
     ])),
  'RLS is enabled on every application table'
);

select ok(
  not has_table_privilege('anon', 'public.stock_movements', 'select')
  and not has_table_privilege('authenticated', 'public.stock_movements', 'insert'),
  'clients never receive direct write grants on the audit ledger'
);

select ok(
  (select count(*) = 26
   from pg_catalog.pg_policy as policy
   join pg_catalog.pg_class as relation on relation.oid = policy.polrelid
   join pg_catalog.pg_namespace as namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'public'),
  'access migration defines the expected explicit policy set'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_update_profile_access(uuid,text,boolean)', 'execute')
  and not has_function_privilege('anon', 'public.admin_update_profile_access(uuid,text,boolean)', 'execute'),
  'only authenticated clients can call the guarded profile access RPC'
);

select ok(
  not has_table_privilege('authenticated', 'public.import_receipts', 'insert')
  and not has_table_privilege('authenticated', 'public.export_receipts', 'update')
  and not has_table_privilege('authenticated', 'public.damage_reports', 'delete'),
  'clients cannot mutate transaction records outside trusted functions'
);

select ok(
  has_column_privilege('authenticated', 'public.profiles', 'display_name', 'update')
  and not has_column_privilege('authenticated', 'public.profiles', 'role', 'update')
  and not has_column_privilege('authenticated', 'public.profiles', 'is_active', 'update'),
  'clients can edit a profile name but cannot self-assign access'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'legacy_auth_uid'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'firebase_uid'
  ),
  'profile identity mapping uses a provider-neutral legacy ID'
);

select ok(
  has_function_privilege('authenticated', 'public.confirm_import_receipt(jsonb,jsonb)', 'execute')
  and has_function_privilege('authenticated', 'public.confirm_export_receipt(jsonb)', 'execute')
  and has_function_privilege('authenticated', 'public.confirm_damage_report(jsonb)', 'execute')
  and has_function_privilege('authenticated', 'public.complete_inventory_check(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.confirm_import_receipt(jsonb,jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.confirm_export_receipt(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.confirm_damage_report(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.complete_inventory_check(jsonb)', 'execute'),
  'only authenticated users can call inventory transaction RPCs'
);

select ok(
  not has_table_privilege('authenticated', 'public.batches', 'insert')
  and not has_table_privilege('authenticated', 'public.batches', 'delete')
  and not has_column_privilege('authenticated', 'public.batches', 'quantity', 'update'),
  'clients cannot create, delete, or directly change stock batches'
);

select ok(
  has_function_privilege('authenticated', 'public.save_rice_product(jsonb)', 'execute')
  and has_function_privilege('authenticated', 'public.delete_rice_product(text)', 'execute')
  and not has_function_privilege('anon', 'public.save_rice_product(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.delete_rice_product(text)', 'execute'),
  'rice catalog writes are limited to authenticated callers of guarded RPCs'
);

select ok(
  (select count(*) = 18
   from pg_catalog.pg_publication_tables
   where pubname = 'supabase_realtime' and schemaname = 'public'),
  'all application tables are enabled for realtime repository streams'
);

select * from finish();
rollback;
