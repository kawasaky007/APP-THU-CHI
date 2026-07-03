-- Allow every household member to read the profile list for their household.
-- This fixes member selection in transaction forms without adding tables/columns.

create or replace function public.current_user_household_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select household_id
  from public.profiles
  where id = auth.uid()
$$;

grant execute on function public.current_user_household_id() to authenticated;

drop policy if exists "Household members can select profiles" on public.profiles;

create policy "Household members can select profiles"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or household_id = public.current_user_household_id()
);
