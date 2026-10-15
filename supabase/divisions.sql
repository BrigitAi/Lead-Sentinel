-- =====================================================================
-- Brigit Trivia League — business divisions (separate from sectors)
-- Run once in the Supabase SQL editor. Safe to re-run.
--
-- * Sectors go back to the original 8.
-- * Every competitor has ONE business division: Finance/Admin, Procurement, Production or Sales.
-- * Anyone who ticked a division as a "sector" during testing is tidied up:
--   it is removed from their sectors (and becomes their division if they ticked exactly one).
-- * The league table view, registered-players list and stats include the division.
-- =====================================================================

-- ---------- Lists (edit here to add or rename) ----------
create or replace function public.quiz_sector_list() returns text[] language sql immutable as $$
  select array['Technical Johannesburg','Exports','Passive Fire Containment','Special Risk',
               'Sprinklers & Valves','Fire Detection','Gas Suppression','Portable Extinguishers']::text[];
$$;
create or replace function public.quiz_division_list() returns text[] language sql immutable as $$
  select array['Finance/Admin','Operations','Procurement','Production','Sales']::text[];
$$;

-- ---------- Profiles: add division, tidy sectors ----------
alter table public.quiz_profiles add column if not exists division text;
alter table public.quiz_profiles drop constraint if exists quiz_profiles_sector_check;
alter table public.quiz_profiles drop constraint if exists quiz_profiles_sectors_check;
alter table public.quiz_profiles drop constraint if exists quiz_profiles_division_check;

-- exactly one division ticked as a sector -> that becomes the division
update public.quiz_profiles p set division = d.only_division
from (
  select user_id, min(s) as only_division
  from public.quiz_profiles, unnest(sectors) s
  where s = any (public.quiz_division_list())
  group by user_id having count(*) = 1
) d
where d.user_id = p.user_id and p.division is null;

-- remove divisions from the sector lists (keep order); never leave a list empty
update public.quiz_profiles set sectors = coalesce(nullif(
  array(select s from unnest(sectors) with ordinality t(s, o) where s = any (public.quiz_sector_list()) order by o),
  '{}'::text[]), public.quiz_sector_list())
where not (sectors <@ public.quiz_sector_list());
update public.quiz_profiles set sector = sectors[1] where not (sector = any (sectors));

-- races played "for" a division count for the player's main sector instead
update public.quiz_results r set sector = p.sector
from public.quiz_profiles p
where p.user_id = r.user_id and r.sector = any (public.quiz_division_list());

alter table public.quiz_profiles add constraint quiz_profiles_sector_check
  check (sector = any (public.quiz_sector_list()));
alter table public.quiz_profiles add constraint quiz_profiles_sectors_check check (
  cardinality(sectors) >= 1 and sectors <@ public.quiz_sector_list() and sector = any (sectors));
-- division is required in the app; existing players without one are asked to choose at next sign-in
alter table public.quiz_profiles add constraint quiz_profiles_division_check
  check (division is null or division = any (public.quiz_division_list()));

-- players may change their own sectors and division (not their name)
revoke update on public.quiz_profiles from authenticated;
grant update (sector, sectors, division) on public.quiz_profiles to authenticated;

-- ---------- League table view: add division ----------
create or replace view public.quiz_results_board with (security_invoker = true) as
  select r.created_at, r.points, r.correct, r.asked, r.library, p.user_id, p.display_name,
         coalesce(r.sector, p.sector) as sector, p.division
  from public.quiz_results r join public.quiz_profiles p on p.user_id = r.user_id;
revoke all on public.quiz_results_board from anon;

-- ---------- Registered players list: add division ----------
drop function if exists public.quiz_registered_players();
create function public.quiz_registered_players()
returns table (
  email text, registered_at timestamptz, email_confirmed boolean, last_sign_in timestamptz,
  league_name text, division text, sectors text, races_played bigint, points bigint, last_played timestamptz,
  did_company_policies boolean
)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.quiz_is_approver() then
    raise exception 'Only approvers can see registered players';
  end if;
  return query
    select u.email::text, u.created_at, u.email_confirmed_at is not null, u.last_sign_in_at,
           p.display_name, p.division, array_to_string(p.sectors, ', '),
           coalesce(r.n_races, 0), coalesce(r.n_points, 0), r.last_at, coalesce(r.did_policies, false)
    from auth.users u
    left join public.quiz_profiles p on p.user_id = u.id
    left join (
      select x.user_id as uid, count(*) as n_races, sum(x.points)::bigint as n_points, max(x.created_at) as last_at,
             bool_or(x.library = 'policies') as did_policies
      from public.quiz_results x group by x.user_id
    ) r on r.uid = u.id
    where u.email ilike '%@brigit.co.za'
       or lower(u.email::text) in (select lower(a.email) from public.quiz_approvers a)
    order by u.created_at desc;
end $$;
revoke all on function public.quiz_registered_players() from public, anon;
grant execute on function public.quiz_registered_players() to authenticated;

-- ---------- Stats for ASH: division table ----------
create or replace view public.quiz_stats_divisions with (security_invoker = true) as
  select rank() over (order by sum(r.points) desc) as rank, coalesce(p.division, 'Not chosen yet') as division,
         sum(r.points) as points, count(*) as races_played, count(distinct r.user_id) as competitors,
         round(100.0 * sum(r.correct) / nullif(sum(r.asked), 0), 1) as accuracy_pct
  from public.quiz_results r join public.quiz_profiles p on p.user_id = r.user_id
  group by coalesce(p.division, 'Not chosen yet')
  order by points desc;
revoke all on public.quiz_stats_divisions from anon;
