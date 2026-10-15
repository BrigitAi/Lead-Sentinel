-- =====================================================================
-- Brigit Trivia League — who may generate questions, Deon as approver, Operations division
-- Run once in the Supabase SQL editor. Safe to re-run.
-- =====================================================================

-- ---------- Add the Operations business division ----------
create or replace function public.quiz_division_list() returns text[] language sql immutable as $$
  select array['Finance/Admin','Operations','Procurement','Production','Sales']::text[];
$$;

-- ---------- Deon van Zyl becomes an approver ----------
insert into public.quiz_approvers (email, name) values ('deon@brigit.co.za', 'Deon van Zyl')
on conflict (email) do update set name = excluded.name;

-- ---------- Only these people may generate questions with AI ----------
create table if not exists public.quiz_generators (
  email text primary key,
  name  text not null
);
alter table public.quiz_generators enable row level security;
revoke all on public.quiz_generators from anon, authenticated;

insert into public.quiz_generators (email, name) values
  ('donald@brigit.co.za',     'Donald Barnard'),
  ('deon@brigit.co.za',       'Deon van Zyl'),
  ('sysproai@elveygroup.com', 'Admin (Elvey Group)')
on conflict (email) do update set name = excluded.name;

create or replace function public.quiz_can_generate()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.quiz_generators g
                 where lower(g.email) = lower(auth.jwt() ->> 'email'));
$$;
revoke all on function public.quiz_can_generate() from public, anon;
grant execute on function public.quiz_can_generate() to authenticated, service_role;
