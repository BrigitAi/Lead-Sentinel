-- =====================================================================
-- Brigit Trivia League — add sectors: Finance/Admin, Procurement, Production, Sales
-- Run once in the Supabase SQL editor. Safe to re-run.
-- From now on the sector list lives in one place: public.quiz_sector_list().
-- =====================================================================
-- ---------- The list of sectors (edit here to add or rename a sector) ----------
create or replace function public.quiz_sector_list() returns text[] language sql immutable as $$
  select array['Technical Johannesburg','Exports','Passive Fire Containment','Special Risk',
    'Sprinklers & Valves','Fire Detection','Gas Suppression','Portable Extinguishers',
    'Finance/Admin','Procurement','Production','Sales']::text[];
$$;

-- Replace the old fixed lists with the shared one
alter table public.quiz_profiles drop constraint if exists quiz_profiles_sector_check;
alter table public.quiz_profiles add constraint quiz_profiles_sector_check
  check (sector = any (public.quiz_sector_list()));

alter table public.quiz_profiles drop constraint if exists quiz_profiles_sectors_check;
alter table public.quiz_profiles add constraint quiz_profiles_sectors_check check (
  cardinality(sectors) >= 1
  and sectors <@ public.quiz_sector_list()
  and sector = any(sectors)
);
