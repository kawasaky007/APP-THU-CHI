create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  month int not null check (month between 1 and 12),
  year int not null check (year >= 2000),
  amount numeric not null check (amount >= 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(household_id, category_id, month, year)
);

create index if not exists budgets_household_month_year_idx
on public.budgets (household_id, year, month);

create index if not exists budgets_category_id_idx
on public.budgets (category_id);

alter table public.budgets enable row level security;

drop policy if exists "Household members can select budgets" on public.budgets;
drop policy if exists "Household members can insert budgets" on public.budgets;
drop policy if exists "Household members can update budgets" on public.budgets;
drop policy if exists "Household members can delete budgets" on public.budgets;

create policy "Household members can select budgets"
on public.budgets
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.household_id = budgets.household_id
  )
);

create policy "Household members can insert budgets"
on public.budgets
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.household_id = budgets.household_id
  )
  and exists (
    select 1
    from public.categories as budget_category
    where budget_category.id = budgets.category_id
      and budget_category.household_id = budgets.household_id
      and budget_category.type = 'expense'
  )
);

create policy "Household members can update budgets"
on public.budgets
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.household_id = budgets.household_id
  )
  and exists (
    select 1
    from public.categories as budget_category
    where budget_category.id = budgets.category_id
      and budget_category.household_id = budgets.household_id
      and budget_category.type = 'expense'
  )
)
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.household_id = budgets.household_id
  )
  and exists (
    select 1
    from public.categories as budget_category
    where budget_category.id = budgets.category_id
      and budget_category.household_id = budgets.household_id
      and budget_category.type = 'expense'
  )
);

create policy "Household members can delete budgets"
on public.budgets
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.household_id = budgets.household_id
  )
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_budgets_updated_at on public.budgets;
create trigger set_budgets_updated_at
before update on public.budgets
for each row
execute function public.set_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'budgets'
  ) then
    alter publication supabase_realtime add table public.budgets;
  end if;
end;
$$;
