-- =====================================================================
-- Brigit Trivia League — Supabase setup
-- Adds quiz tables next to ASH's library. Does NOT change any ASH table.
-- Safe to run more than once.
-- =====================================================================

-- ---------- Approvers (can review questions) ----------
create table if not exists public.quiz_approvers (
  email text primary key,
  name  text not null
);

-- ---------- Competitor profiles ----------
create table if not exists public.quiz_profiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 30),
  sector       text not null check (sector in (
                 'Technical Johannesburg','Exports','Passive Fire Containment','Special Risk',
                 'Sprinklers & Valves','Fire Detection','Gas Suppression','Portable Extinguishers')),
  created_at   timestamptz not null default now()
);

-- ---------- Questions ----------
create table if not exists public.quiz_questions (
  id            uuid primary key default gen_random_uuid(),
  library       text not null check (library in (
                  'fire','policies','datasheets','sds','ops','certification')),
  question      text not null,
  options       text[] not null check (array_length(options, 1) = 4),
  correct_index smallint not null check (correct_index between 0 and 3),
  explanation   text,
  source_table  text,          -- e.g. fire_standards, msds_sheets
  source_id     text,          -- id of the document in that table
  source_title  text,          -- shown to players as the reference
  status        text not null default 'draft' check (status in ('draft','approved','rejected')),
  review_note   text,
  reviewed_by   text,
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists quiz_questions_status_library on public.quiz_questions (status, library);

-- ---------- Results (one row per race) ----------
create table if not exists public.quiz_results (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  library     text not null,
  points      integer not null check (points between 0 and 10000),
  correct     smallint not null check (correct >= 0),
  asked       smallint not null check (asked between 1 and 20 and correct <= asked),
  best_streak smallint not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists quiz_results_created on public.quiz_results (created_at);

-- ---------- Helper: is the signed-in user an approver? ----------
create or replace function public.quiz_is_approver()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.quiz_approvers a
                 where lower(a.email) = lower(auth.jwt() ->> 'email'));
$$;

-- ---------- Helper: is the signed-in user a Brigit email? ----------
-- Enforced inside the quiz tables only, so other apps in this project are unaffected.
create or replace function public.quiz_is_brigit()
returns boolean language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) like '%@brigit.co.za';
$$;

-- ---------- Row level security ----------
alter table public.quiz_approvers enable row level security;
alter table public.quiz_profiles  enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_results   enable row level security;

-- approvers: signed-in users can see who the approvers are
drop policy if exists "approvers readable" on public.quiz_approvers;
create policy "approvers readable" on public.quiz_approvers for select to authenticated using (public.quiz_is_brigit());

-- profiles: everyone signed in can see names/sectors (for the league table); you edit only your own
drop policy if exists "profiles readable" on public.quiz_profiles;
create policy "profiles readable" on public.quiz_profiles for select to authenticated using (public.quiz_is_brigit());
drop policy if exists "profiles insert own" on public.quiz_profiles;
create policy "profiles insert own" on public.quiz_profiles for insert to authenticated with check (user_id = auth.uid() and public.quiz_is_brigit());
-- no update policy: name and sector are locked once chosen (an admin can change them in the dashboard)
drop policy if exists "profiles update own" on public.quiz_profiles;

-- questions: players see approved only; approvers see and review everything
drop policy if exists "questions approved readable" on public.quiz_questions;
create policy "questions approved readable" on public.quiz_questions for select to authenticated
  using ((status = 'approved' and public.quiz_is_brigit()) or public.quiz_is_approver());
drop policy if exists "questions approver update" on public.quiz_questions;
create policy "questions approver update" on public.quiz_questions for update to authenticated
  using (public.quiz_is_approver()) with check (public.quiz_is_approver());

-- results: everyone signed in can read (league table); you can only add your own; no edits/deletes
drop policy if exists "results readable" on public.quiz_results;
create policy "results readable" on public.quiz_results for select to authenticated using (public.quiz_is_brigit());
drop policy if exists "results insert own" on public.quiz_results;
create policy "results insert own" on public.quiz_results for insert to authenticated with check (user_id = auth.uid() and public.quiz_is_brigit());

-- ---------- Signed-out visitors get nothing ----------
revoke all on public.quiz_approvers, public.quiz_profiles, public.quiz_questions, public.quiz_results from anon;

-- ---------- League table view (results + names + sectors) ----------
create or replace view public.quiz_results_board with (security_invoker = true) as
  select r.created_at, r.points, r.correct, r.asked, r.library, p.user_id, p.display_name, p.sector
  from public.quiz_results r join public.quiz_profiles p on p.user_id = r.user_id;

revoke all on public.quiz_results_board from anon;

-- ---------- Approvers ----------
insert into public.quiz_approvers (email, name) values
  ('donald@brigit.co.za', 'Donald'),
  ('corne@brigit.co.za',  'Corne'),
  ('feri@brigit.co.za',   'Feri')
on conflict (email) do update set name = excluded.name;
