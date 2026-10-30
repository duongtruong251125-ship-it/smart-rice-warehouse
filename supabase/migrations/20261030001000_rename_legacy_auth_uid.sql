-- Retain imported identity mappings while removing the previous provider name.
do $$
declare
  has_old_name boolean;
  has_new_name boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'firebase_uid'
  ) into has_old_name;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'legacy_auth_uid'
  ) into has_new_name;

  if has_old_name and has_new_name then
    raise exception 'Both identity mapping columns exist; review before renaming.';
  elsif has_old_name then
    alter table public.profiles rename column firebase_uid to legacy_auth_uid;
  end if;
end;
$$;
