-- =====================================================================
-- Brigit Trivia League — multiple sectors per competitor
-- Run once in the Supabase SQL editor (after schema.sql). Safe to re-run.
-- Run this BEFORE uploading the new game files.
--
-- * Competitors can belong to several sectors (quiz_profiles.sectors).
-- * Every race is played for one of those sectors (quiz_results.sector),
--   so the league table is per competitor per sector, and sector totals
--   never count the same race twice.
-- =====================================================================

-- ---------- Profiles: list of sectors ----------
alter table public.quiz_profiles add column if not exists sectors text[];
update public.quiz_profiles set sectors = array[sector] where sectors is null or cardinality(sectors) = 0;
alter table public.quiz_profiles alter column sectors set not null;

alter table public.quiz_profiles drop constraint if exists quiz_profiles_sectors_check;
alter table public.quiz_profiles add constraint quiz_profiles_sectors_check check (
  cardinality(sectors) >= 1
  and sectors <@ public.quiz_sector_list()
  and sector = any(sectors)        -- "sector" stays as the main sector
);

-- ---------- Results: which sector each race was played for ----------
alter table public.quiz_results add column if not exists sector text;
update public.quiz_results r set sector = p.sector
  from public.quiz_profiles p where p.user_id = r.user_id and r.sector is null;

-- You can only play for a sector you belong to.
-- (A missing sector is still accepted so older copies of the game keep working; it counts for the main sector.)
drop policy if exists "results insert own" on public.quiz_results;
create policy "results insert own" on public.quiz_results for insert to authenticated with check (
  user_id = auth.uid() and public.quiz_is_brigit()
  and (sector is null or sector = any(coalesce((select p.sectors from public.quiz_profiles p where p.user_id = auth.uid()), '{}'::text[])))
);

-- ---------- League table view: sector now comes from the race ----------
create or replace view public.quiz_results_board with (security_invoker = true) as
  select r.created_at, r.points, r.correct, r.asked, r.library, p.user_id, p.display_name,
         coalesce(r.sector, p.sector) as sector
  from public.quiz_results r join public.quiz_profiles p on p.user_id = r.user_id;

revoke all on public.quiz_results_board from anon;
