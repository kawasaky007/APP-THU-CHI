-- Add display_order column to budgets table for drag-and-drop sorting
alter table public.budgets
  add column if not exists display_order integer default 0;

-- Backfill existing rows: assign sequential order based on created_at
with ordered as (
  select id,
         row_number() over (
           partition by household_id, month, year
           order by created_at
         ) - 1 as rn
  from public.budgets
)
update public.budgets
set display_order = ordered.rn
from ordered
where public.budgets.id = ordered.id;

-- Create index for efficient ordering
create index if not exists budgets_display_order_idx
on public.budgets (household_id, year, month, display_order);
