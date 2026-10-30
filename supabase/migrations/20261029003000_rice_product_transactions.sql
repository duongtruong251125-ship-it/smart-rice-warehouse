-- Keep a product and its many-to-many characteristics consistent in one
-- transaction instead of exposing partial updates from a mobile client.

create or replace function public.save_rice_product(payload_product jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  product_id text := btrim(payload_product ->> 'id');
  product_code text := btrim(payload_product ->> 'code');
  product_name text := btrim(payload_product ->> 'name');
  characteristic_ids text[];
begin
  if not public.current_profile_is_admin() then
    raise exception using errcode = '42501', message = 'Admin role required';
  end if;
  if jsonb_typeof(payload_product) is distinct from 'object'
     or product_id is null or product_id = '' or product_code is null or product_code = ''
     or product_name is null or product_name = ''
     or position('/' in product_id) > 0 then
    raise exception using errcode = '22023', message = 'Rice product is invalid';
  end if;

  if jsonb_typeof(coalesce(payload_product -> 'characteristicIds', '[]'::jsonb)) is distinct from 'array' then
    raise exception using errcode = '22023', message = 'Rice characteristics are invalid';
  end if;
  select coalesce(array_agg(distinct value #>> '{}'), '{}'::text[])
  into characteristic_ids
  from jsonb_array_elements(coalesce(payload_product -> 'characteristicIds', '[]'::jsonb));
  if exists (
    select 1 from unnest(characteristic_ids) as selected(id)
    where selected.id is null or selected.id = ''
  ) or cardinality(characteristic_ids) <> jsonb_array_length(
    coalesce(payload_product -> 'characteristicIds', '[]'::jsonb)
  ) then
    raise exception using errcode = '22023', message = 'Rice characteristics contain invalid or duplicate IDs';
  end if;
  if cardinality(characteristic_ids) > 0 and (
    select count(*) from public.rice_characteristics
    where id = any(characteristic_ids)
  ) <> cardinality(characteristic_ids) then
    raise exception using errcode = '23503', message = 'Rice characteristic not found';
  end if;

  insert into public.rice_products (
    id, code, name, category, unit, purchase_price, selling_price,
    minimum_stock, description, is_active, image_path
  ) values (
    product_id, product_code, product_name,
    coalesce(payload_product ->> 'category', ''),
    coalesce(payload_product ->> 'unit', 'kg'),
    coalesce((payload_product ->> 'purchasePrice')::numeric, 0),
    coalesce((payload_product ->> 'sellingPrice')::numeric, 0),
    coalesce((payload_product ->> 'minimumStock')::numeric, 0),
    coalesce(payload_product ->> 'description', ''),
    coalesce((payload_product ->> 'isActive')::boolean, true),
    nullif(payload_product ->> 'imagePath', '')
  ) on conflict (id) do update set
    code = excluded.code,
    name = excluded.name,
    category = excluded.category,
    unit = excluded.unit,
    purchase_price = excluded.purchase_price,
    selling_price = excluded.selling_price,
    minimum_stock = excluded.minimum_stock,
    description = excluded.description,
    is_active = excluded.is_active,
    image_path = excluded.image_path;

  delete from public.rice_product_characteristics where rice_id = product_id;
  if cardinality(characteristic_ids) > 0 then
    insert into public.rice_product_characteristics (rice_id, characteristic_id)
    select product_id, selected.id from unnest(characteristic_ids) as selected(id);
  end if;
end;
$$;

create or replace function public.delete_rice_product(target_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception using errcode = '42501', message = 'Admin role required';
  end if;
  delete from public.rice_products where id = btrim(target_id);
  if not found then
    raise exception using errcode = 'P0002', message = 'Rice product not found';
  end if;
end;
$$;

revoke all on function public.save_rice_product(jsonb) from public, anon, authenticated;
revoke all on function public.delete_rice_product(text) from public, anon, authenticated;
grant execute on function public.save_rice_product(jsonb) to authenticated;
grant execute on function public.delete_rice_product(text) to authenticated;
