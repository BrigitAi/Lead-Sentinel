-- =====================================================================
-- Brigit Trivia League — stats for ASH (and reports)
-- Run once in the Supabase SQL editor (after schema.sql and sectors.sql). Safe to re-run.
-- Creates read-only views ASH can query like tables. Times are South African time.
-- =====================================================================

-- ---------- Per-answer log (filled by the game from now on) ----------
create table if not exists public.quiz_answers (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  question_id uuid references public.quiz_questions(id) on delete set null,
  library     text,
  sector      text,
  correct     boolean not null,
  timed_out   boolean not null default false,
  seconds     numeric(5,1),
  points      integer not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists quiz_answers_question on public.quiz_answers (question_id);
create index if not exists quiz_answers_user on public.quiz_answers (user_id, question_id);
alter table public.quiz_answers enable row level security;
drop policy if exists "answers insert own" on public.quiz_answers;
create policy "answers insert own" on public.quiz_answers for insert to authenticated
  with check (user_id = auth.uid() and public.quiz_is_brigit());
drop policy if exists "answers readable" on public.quiz_answers;
create policy "answers readable" on public.quiz_answers for select to authenticated using (public.quiz_is_brigit());
revoke all on public.quiz_answers from anon;

-- Start clean so the views can be re-created safely
drop function if exists public.quiz_stats_summary();
drop view if exists public.quiz_stats_leaderboard, public.quiz_stats_leaderboard_by_sector, public.quiz_stats_sectors,
  public.quiz_stats_most_played, public.quiz_stats_question_repeats, public.quiz_stats_questions,
  public.quiz_stats_play_hours, public.quiz_stats_play_times, public.quiz_stats_required_completion, public.quiz_stats_divisions, public.quiz_stats_races cascade;

-- Friendly race names
create or replace function public.quiz_race_name(lib text) returns text language sql immutable as $$
  select case lib when 'fire' then 'Fire Standards' when 'policies' then 'Company Policies' when 'datasheets' then 'Datasheets'
    when 'sds' then 'Safety Data Sheets' when 'ops' then 'Operational Manuals' when 'certification' then 'Product Certification'
    when 'mixed' then 'Mixed Bag' else lib end;
$$;

-- Helper: one row per race with player name and SA local time
create or replace view public.quiz_stats_races with (security_invoker = true) as
  select r.id, r.created_at, (r.created_at at time zone 'Africa/Johannesburg') as played_at_sa,
         r.user_id, p.display_name as competitor, coalesce(r.sector, p.sector) as sector,
         public.quiz_race_name(r.library) as race, r.points, r.correct, r.asked, r.best_streak,
         coalesce(p.division, 'Not chosen yet') as division
  from public.quiz_results r join public.quiz_profiles p on p.user_id = r.user_id;

-- 1) WHO IS IN THE LEAD — competitors (all races, all sectors), with week / month / season totals
create or replace view public.quiz_stats_leaderboard with (security_invoker = true) as
  select rank() over (order by sum(points) desc) as rank,
         competitor, division,
         string_agg(distinct sector, ', ') as sectors_played_for,
         sum(points)                                                        as season_points,
         sum(points) filter (where played_at_sa >= date_trunc('month', now() at time zone 'Africa/Johannesburg')) as month_points,
         sum(points) filter (where played_at_sa >= (now() at time zone 'Africa/Johannesburg') - interval '7 days')  as week_points,
         count(*)                                                           as races_played,
         max(points)                                                        as best_race,
         round(100.0 * sum(correct) / nullif(sum(asked), 0), 1)             as accuracy_pct,
         max(played_at_sa)                                                  as last_played_sa
  from public.quiz_stats_races
  group by user_id, competitor, division
  order by season_points desc;

-- 1b) Leaderboard per competitor per sector (matches the game's table)
create or replace view public.quiz_stats_leaderboard_by_sector with (security_invoker = true) as
  select sector, rank() over (partition by sector order by sum(points) desc) as rank_in_sector,
         competitor, sum(points) as points, count(*) as races_played,
         round(100.0 * sum(correct) / nullif(sum(asked), 0), 1) as accuracy_pct
  from public.quiz_stats_races
  group by sector, user_id, competitor
  order by sector, points desc;

-- 1c) Sector table
create or replace view public.quiz_stats_sectors with (security_invoker = true) as
  select rank() over (order by sum(points) desc) as rank, sector,
         sum(points) as points, count(*) as races_played, count(distinct user_id) as competitors,
         round(100.0 * sum(correct) / nullif(sum(asked), 0), 1) as accuracy_pct
  from public.quiz_stats_races
  group by sector
  order by points desc;

-- 1d) Business division table
create or replace view public.quiz_stats_divisions with (security_invoker = true) as
  select rank() over (order by sum(points) desc) as rank, division,
         sum(points) as points, count(*) as races_played, count(distinct user_id) as competitors,
         round(100.0 * sum(correct) / nullif(sum(asked), 0), 1) as accuracy_pct
  from public.quiz_stats_races
  group by division
  order by points desc;

-- 2) WHO PLAYS THE MOST — races per competitor per race type (e.g. Company Policies)
create or replace view public.quiz_stats_most_played with (security_invoker = true) as
  select race, rank() over (partition by race order by count(*) desc) as rank_in_race,
         competitor, count(*) as races_played, sum(points) as points, max(points) as best_race,
         round(100.0 * sum(correct) / nullif(sum(asked), 0), 1) as accuracy_pct,
         min(played_at_sa) as first_played_sa, max(played_at_sa) as last_played_sa
  from public.quiz_stats_races
  group by race, user_id, competitor
  order by race, races_played desc;

-- 2b) WHO ANSWERED THE SAME QUESTIONS MOST OFTEN (from the answer log)
create or replace view public.quiz_stats_question_repeats with (security_invoker = true) as
  select p.display_name as competitor, public.quiz_race_name(q.library) as race, q.question,
         count(*) as times_answered, count(*) filter (where a.correct) as times_correct,
         round(avg(a.seconds), 1) as avg_seconds, max(a.created_at at time zone 'Africa/Johannesburg') as last_answered_sa
  from public.quiz_answers a
  join public.quiz_profiles p on p.user_id = a.user_id
  join public.quiz_questions q on q.id = a.question_id
  group by p.display_name, a.user_id, q.id, q.library, q.question
  having count(*) > 1
  order by times_answered desc;

-- 2c) Question difficulty: most played, most missed
create or replace view public.quiz_stats_questions with (security_invoker = true) as
  select public.quiz_race_name(q.library) as race, q.question, q.source_title as reference,
         count(*) as times_answered, count(distinct a.user_id) as competitors,
         round(100.0 * count(*) filter (where a.correct) / count(*), 1) as pct_correct,
         count(*) filter (where a.timed_out) as times_timed_out, round(avg(a.seconds), 1) as avg_seconds
  from public.quiz_answers a join public.quiz_questions q on q.id = a.question_id
  group by q.id, q.library, q.question, q.source_title
  order by times_answered desc;

-- 3) WHEN DO THEY PLAY — by hour of day (SA time)
create or replace view public.quiz_stats_play_hours with (security_invoker = true) as
  select extract(hour from played_at_sa)::int as hour_of_day,
         to_char(date_trunc('hour', played_at_sa), 'HH24:00') || '–' || to_char(date_trunc('hour', played_at_sa) + interval '1 hour', 'HH24:00') as time_slot,
         count(*) as races_played, count(distinct user_id) as competitors
  from public.quiz_stats_races
  group by 1, 2
  order by races_played desc;

-- 3b) By weekday and hour
create or replace view public.quiz_stats_play_times with (security_invoker = true) as
  select extract(isodow from played_at_sa)::int as weekday_no, to_char(played_at_sa, 'FMDay') as weekday,
         extract(hour from played_at_sa)::int as hour_of_day, count(*) as races_played, count(distinct user_id) as competitors
  from public.quiz_stats_races
  group by 1, 2, 3
  order by races_played desc;

-- 4) Required race (Company Policies): who has / hasn't completed it
create or replace view public.quiz_stats_required_completion with (security_invoker = true) as
  select p.display_name as competitor, array_to_string(p.sectors, ', ') as sectors,
         (min(r.created_at) is not null) as completed,
         min(r.created_at at time zone 'Africa/Johannesburg') as first_completed_sa, max(r.points) as best_score
  from public.quiz_profiles p
  left join public.quiz_results r on r.user_id = p.user_id and r.library = 'policies'
  group by p.user_id, p.display_name, p.sectors
  order by completed, competitor;

-- 5) One-call summary (JSON) — handy for ASH
create or replace function public.quiz_stats_summary()
returns jsonb language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'generated_at_sa',  now() at time zone 'Africa/Johannesburg',
    'leaders',          (select coalesce(jsonb_agg(l), '[]') from (select rank, competitor, division, season_points, races_played, accuracy_pct from quiz_stats_leaderboard limit 10) l),
    'sectors',          (select coalesce(jsonb_agg(s), '[]') from (select rank, sector, points, races_played, competitors from quiz_stats_sectors) s),
    'divisions',        (select coalesce(jsonb_agg(d), '[]') from (select rank, division, points, races_played, competitors from quiz_stats_divisions) d),
    'most_races',       (select coalesce(jsonb_agg(m), '[]') from (select competitor, sum(races_played) as races_played from quiz_stats_most_played group by competitor order by 2 desc limit 10) m),
    'most_played_by_race', (select coalesce(jsonb_agg(m), '[]') from (select race, competitor, races_played from quiz_stats_most_played where rank_in_race = 1) m),
    'busiest_hours',    (select coalesce(jsonb_agg(h), '[]') from (select time_slot, races_played, competitors from quiz_stats_play_hours limit 5) h),
    'company_policies', (select jsonb_build_object('completed', count(*) filter (where completed), 'not_completed', count(*) filter (where not completed)) from quiz_stats_required_completion),
    'hardest_questions',(select coalesce(jsonb_agg(q), '[]') from (select race, question, pct_correct, times_answered from quiz_stats_questions where times_answered >= 5 order by pct_correct asc limit 5) q)
  );
$$;

-- Nobody signed-out can read stats
revoke all on public.quiz_stats_races, public.quiz_stats_leaderboard, public.quiz_stats_leaderboard_by_sector,
  public.quiz_stats_sectors, public.quiz_stats_divisions, public.quiz_stats_most_played, public.quiz_stats_question_repeats,
  public.quiz_stats_questions, public.quiz_stats_play_hours, public.quiz_stats_play_times,
  public.quiz_stats_required_completion from anon;
revoke all on function public.quiz_stats_summary() from public, anon;
grant execute on function public.quiz_stats_summary() to authenticated, service_role;
