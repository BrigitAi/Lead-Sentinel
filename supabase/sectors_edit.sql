-- =====================================================================
-- Brigit Trivia League — let competitors change their own sectors
-- Run once in the Supabase SQL editor (after sectors.sql). Safe to re-run.
-- Display names stay fixed; only sectors and business division can be changed.
-- Races already played keep the sector they were played for.
-- =====================================================================
drop policy if exists "profiles update own sectors" on public.quiz_profiles;
create policy "profiles update own sectors" on public.quiz_profiles for update to authenticated
  using (user_id = auth.uid() and public.quiz_is_brigit())
  with check (user_id = auth.uid() and public.quiz_is_brigit());

-- Only the sector columns may be changed by players
revoke update on public.quiz_profiles from authenticated;
grant update (sector, sectors, division) on public.quiz_profiles to authenticated;
