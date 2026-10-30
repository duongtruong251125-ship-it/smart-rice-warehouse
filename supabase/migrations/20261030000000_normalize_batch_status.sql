-- Keep the user-visible batch status consistent with quantity and expiry for
-- every stock transaction, regardless of which trusted RPC changed the row.
create or replace function public.normalize_batch_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.expiry_date < (pg_catalog.now() at time zone 'Asia/Ho_Chi_Minh')::date then
    new.status := 'expired';
  elsif new.status = 'qualityHold' or new.quantity <= 0 then
    new.status := 'qualityHold';
  elsif new.quantity <= 100 then
    new.status := 'lowStock';
  else
    new.status := 'available';
  end if;
  return new;
end;
$$;

revoke all on function public.normalize_batch_status()
  from public, anon, authenticated;

drop trigger if exists batches_normalize_status on public.batches;
create trigger batches_normalize_status
  before insert or update on public.batches
  for each row execute function public.normalize_batch_status();

-- Repair any status drift created by earlier RPC versions without changing
-- stock quantities or generating movement entries.
update public.batches
set status = case
  when expiry_date < (pg_catalog.now() at time zone 'Asia/Ho_Chi_Minh')::date
    then 'expired'
  when status = 'qualityHold' or quantity <= 0 then 'qualityHold'
  when quantity <= 100 then 'lowStock'
  else 'available'
end;
