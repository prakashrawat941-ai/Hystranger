create extension if not exists pgcrypto;
do $$ begin create type public.trip_status as enum ('open','full','cancelled','completed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.join_status as enum ('pending','approved','declined','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.trip_join_policy as enum ('approval','instant'); exception when duplicate_object then null; end $$;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null check(char_length(full_name) between 2 and 80),
 avatar_url text, date_of_birth date, gender text check(gender in ('male','female','non_binary','prefer_not_to_say')),
 city text, bio text check(char_length(coalesce(bio,''))<=500), interests text[] not null default '{}',
 phone_verified boolean not null default false, identity_verified boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.trips (
 id uuid primary key default gen_random_uuid(), host_id uuid not null references public.profiles(id) on delete restrict,
 destination text not null check(char_length(destination) between 2 and 120), region text,
 start_date date not null, end_date date not null, departure_city text not null,
 budget_amount integer not null check(budget_amount>=0), trip_type text not null,
 gender_preference text not null default 'Any' check(gender_preference in ('Any','Male only','Female only')),
 min_age smallint, max_age smallint, max_group_size smallint not null default 4 check(max_group_size between 2 and 20),
 cover_image_url text, description text, itinerary jsonb not null default '[]'::jsonb,
 join_policy public.trip_join_policy not null default 'approval', status public.trip_status not null default 'open',
 created_at timestamptz not null default now(), check(end_date>=start_date),
 check(min_age is null or max_age is null or max_age>=min_age)
);
create table if not exists public.join_requests (
 id uuid primary key default gen_random_uuid(), trip_id uuid not null references public.trips(id) on delete cascade,
 requester_id uuid not null references public.profiles(id) on delete cascade,
 note text not null check(char_length(note) between 1 and 500), status public.join_status not null default 'pending',
 created_at timestamptz not null default now(), unique(trip_id,requester_id)
);
create table if not exists public.trip_members (
 trip_id uuid not null references public.trips(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, joined_at timestamptz not null default now(),
 primary key(trip_id,user_id)
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(), trip_id uuid not null references public.trips(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 4000), created_at timestamptz not null default now()
);
create table if not exists public.reports (
 id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id) on delete cascade,
 reported_user_id uuid references public.profiles(id) on delete set null, trip_id uuid references public.trips(id) on delete set null,
 reason text not null, details text check(char_length(coalesce(details,''))<=2000), created_at timestamptz not null default now()
);
create table if not exists public.blocks (
 blocker_id uuid not null references public.profiles(id) on delete cascade, blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(blocker_id,blocked_id), check(blocker_id<>blocked_id)
);
create index if not exists trips_open_start_idx on public.trips(start_date) where status='open';
create index if not exists trips_destination_idx on public.trips using gin(to_tsvector('simple',destination));
create index if not exists trips_host_idx on public.trips(host_id);
create index if not exists join_requests_trip_status_idx on public.join_requests(trip_id,status);
create index if not exists messages_trip_created_idx on public.messages(trip_id,created_at);
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',split_part(coalesce(new.email,'traveller'),'@',1))); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.is_trip_host(tid uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.trips where id=tid and host_id=auth.uid()) $$;
create or replace function public.is_trip_member(tid uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.trip_members where trip_id=tid and user_id=auth.uid()) $$;
create or replace function public.add_trip_host_member() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.trip_members(trip_id,user_id) values(new.id,new.host_id) on conflict do nothing; return new; end $$;
drop trigger if exists trip_host_membership on public.trips;
create trigger trip_host_membership after insert on public.trips for each row execute procedure public.add_trip_host_member();
alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.join_requests enable row level security;
alter table public.trip_members enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
drop policy if exists profile_read on public.profiles;
create policy profile_read on public.profiles for select to authenticated using(true);
drop policy if exists profile_insert on public.profiles;
create policy profile_insert on public.profiles for insert to authenticated with check(id=auth.uid());
drop policy if exists profile_update on public.profiles;
create policy profile_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
drop policy if exists trip_read on public.trips;
create policy trip_read on public.trips for select to authenticated using(status='open' or host_id=auth.uid() or public.is_trip_member(id));
drop policy if exists trip_insert on public.trips;
create policy trip_insert on public.trips for insert to authenticated with check(host_id=auth.uid());
drop policy if exists trip_update on public.trips;
create policy trip_update on public.trips for update to authenticated using(host_id=auth.uid()) with check(host_id=auth.uid());
drop policy if exists trip_delete on public.trips;
create policy trip_delete on public.trips for delete to authenticated using(host_id=auth.uid());
drop policy if exists requests_read on public.join_requests;
create policy requests_read on public.join_requests for select to authenticated using(requester_id=auth.uid() or public.is_trip_host(trip_id));
drop policy if exists members_read on public.trip_members;
create policy members_read on public.trip_members for select to authenticated using(user_id=auth.uid() or public.is_trip_host(trip_id) or public.is_trip_member(trip_id));
drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages for select to authenticated using(public.is_trip_member(trip_id) or public.is_trip_host(trip_id));
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated with check(sender_id=auth.uid() and (public.is_trip_member(trip_id) or public.is_trip_host(trip_id)));
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports for insert to authenticated with check(reporter_id=auth.uid());
drop policy if exists blocks_read on public.blocks;
create policy blocks_read on public.blocks for select to authenticated using(blocker_id=auth.uid());
drop policy if exists blocks_insert on public.blocks;
create policy blocks_insert on public.blocks for insert to authenticated with check(blocker_id=auth.uid());
drop policy if exists blocks_delete on public.blocks;
create policy blocks_delete on public.blocks for delete to authenticated using(blocker_id=auth.uid());
create or replace function public.request_trip_join(target_trip uuid, request_note text) returns public.join_requests language plpgsql security definer set search_path='' as $$
declare t public.trips; req public.join_requests; members integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if char_length(trim(coalesce(request_note,''))) not between 1 and 500 then raise exception 'Message must be 1-500 characters'; end if;
 select * into t from public.trips where id=target_trip for update;
 if not found or t.status<>'open' then raise exception 'Trip unavailable'; end if;
 if t.host_id=auth.uid() then raise exception 'Host cannot join own trip'; end if;
 if exists(select 1 from public.blocks where (blocker_id=auth.uid() and blocked_id=t.host_id) or (blocker_id=t.host_id and blocked_id=auth.uid())) then raise exception 'Connection unavailable'; end if;
 select count(*) into members from public.trip_members where trip_id=target_trip;
 if members>=t.max_group_size then raise exception 'No open spots'; end if;
 insert into public.join_requests(trip_id,requester_id,note,status) values(target_trip,auth.uid(),trim(request_note),case when t.join_policy='instant' then 'approved'::public.join_status else 'pending'::public.join_status) returning * into req;
 if t.join_policy='instant' then insert into public.trip_members(trip_id,user_id) values(target_trip,auth.uid()) on conflict do nothing; end if;
 select count(*) into members from public.trip_members where trip_id=target_trip;
 if members>=t.max_group_size then update public.trips set status='full' where id=target_trip; end if;
 return req;
end $$;
create or replace function public.approve_trip_join_request(target_request uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.join_requests; t public.trips; members integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into r from public.join_requests where id=target_request for update;
 if not found then raise exception 'Request not found'; end if;
 select * into t from public.trips where id=r.trip_id for update;
 if t.host_id<>auth.uid() then raise exception 'Only host can approve'; end if;
 if r.status<>'pending' or t.status<>'open' then raise exception 'Request or trip is no longer available'; end if;
 if exists(select 1 from public.blocks where (blocker_id=auth.uid() and blocked_id=r.requester_id) or (blocker_id=r.requester_id and blocked_id=auth.uid())) then raise exception 'Connection unavailable'; end if;
 select count(*) into members from public.trip_members where trip_id=r.trip_id;
 if members>=t.max_group_size then raise exception 'No open spots'; end if;
 update public.join_requests set status='approved' where id=target_request;
 insert into public.trip_members(trip_id,user_id) values(r.trip_id,r.requester_id) on conflict do nothing;
 select count(*) into members from public.trip_members where trip_id=r.trip_id;
 if members>=t.max_group_size then update public.trips set status='full' where id=r.trip_id; end if;
end $$;
revoke all on function public.request_trip_join(uuid,text) from public;
revoke all on function public.approve_trip_join_request(uuid) from public;
grant execute on function public.request_trip_join(uuid,text) to authenticated;
grant execute on function public.approve_trip_join_request(uuid) to authenticated;
