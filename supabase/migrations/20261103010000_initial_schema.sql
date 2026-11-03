create extension if not exists pgcrypto with schema extensions;

create table public.organization_settings (
  id boolean primary key default true check (id),
  default_starting_score_tenths bigint not null default 50,
  floor_tenths bigint,
  ceiling_tenths bigint,
  updated_at timestamptz not null default now(),
  check (floor_tenths is null or ceiling_tenths is null or floor_tenths <= ceiling_tenths)
);

insert into public.organization_settings (id) values (true) on conflict (id) do nothing;

create table public.staff (
  id uuid primary key default extensions.gen_random_uuid(),
  staff_code text not null check (length(trim(staff_code)) between 1 and 40),
  full_name text not null check (length(trim(full_name)) between 1 and 160),
  department text check (department is null or length(trim(department)) <= 120),
  starting_score_tenths bigint not null default 50,
  current_score_tenths bigint not null default 50,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index staff_code_casefold_unique on public.staff (lower(staff_code));
create index staff_active_name_idx on public.staff (is_archived, lower(full_name));

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text not null check (length(trim(display_name)) between 1 and 160),
  role text not null check (role in ('owner', 'ceo', 'staff')),
  staff_id uuid unique references public.staff (id) on delete restrict,
  is_active boolean not null default true,
  must_set_password boolean not null default true,
  created_at timestamptz not null default now(),
  check ((role = 'staff' and staff_id is not null) or (role <> 'staff' and staff_id is null))
);

create unique index one_owner_only on public.profiles ((role)) where role = 'owner';
create unique index one_ceo_only on public.profiles ((role)) where role = 'ceo';

create table public.merit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  staff_id uuid not null references public.staff (id) on delete restrict,
  actor_id uuid references auth.users (id) on delete set null,
  event_type text not null check (event_type in ('opening', 'adjustment', 'correction')),
  delta_tenths integer not null,
  score_before_tenths bigint,
  score_after_tenths bigint not null,
  reason text not null check (length(trim(reason)) between 1 and 500),
  request_id uuid,
  created_at timestamptz not null default now(),
  check ((event_type = 'opening' and score_before_tenths is null) or (event_type <> 'opening' and score_before_tenths is not null)),
  check (event_type <> 'adjustment' or (abs(delta_tenths) between 10 and 100 and abs(delta_tenths) % 10 = 0)),
  unique (actor_id, request_id)
);

create index merit_events_staff_created_idx on public.merit_events (staff_id, created_at desc);

create table public.audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  action text not null check (length(action) between 1 and 80),
  target_type text not null check (length(target_type) between 1 and 40),
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb check (octet_length(metadata::text) <= 4000),
  created_at timestamptz not null default now()
);

create index audit_events_created_idx on public.audit_events (created_at desc);

create function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_active and case
      when p.role = 'owner' then auth.jwt() ->> 'aal' = 'aal2'
      when p.role = 'ceo' then permission_key in (
        'account.read.self', 'staff.read.all', 'staff.create', 'staff.update',
        'staff.archive', 'merit.read.all', 'merit.adjust', 'merit.correct',
        'csv.import', 'reports.read', 'reports.export', 'system.health.read'
      ) and auth.jwt() ->> 'aal' = 'aal2'
      when p.role = 'staff' then permission_key in ('account.read.self', 'merit.read.self')
      else false
    end
    from public.profiles p where p.user_id = auth.uid()
  ), false);
$$;

create function public.can_read_staff(target_staff_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_permission('staff.read.all') or exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.is_active and p.role = 'staff' and p.staff_id = target_staff_id
  );
$$;

create function public.complete_password_setup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  update public.profiles set must_set_password = false
  where user_id = v_actor and must_set_password = true;
  if not found then raise exception 'Password setup is not pending'; end if;
  insert into public.audit_events (actor_id, action, target_type, target_id)
  values (v_actor, 'account.password_set', 'profile', v_actor);
end;
$$;

create function public.create_staff(
  staff_code_input text,
  full_name_input text,
  department_input text default null,
  starting_score_tenths_input integer default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_score bigint;
  v_floor bigint;
  v_ceiling bigint;
  v_id uuid;
begin
  if v_actor is null or not public.has_permission('staff.create') then raise exception 'Not authorized'; end if;
  if length(trim(coalesce(staff_code_input, ''))) not between 1 and 40 then raise exception 'Staff code is required'; end if;
  if length(trim(coalesce(full_name_input, ''))) not between 1 and 160 then raise exception 'Name is required'; end if;

  select coalesce(starting_score_tenths_input, default_starting_score_tenths), floor_tenths, ceiling_tenths
  into v_score, v_floor, v_ceiling from public.organization_settings where id = true;

  if v_score is null then raise exception 'Organization settings are missing'; end if;
  if v_floor is not null and v_score < v_floor then raise exception 'Starting score is below the configured minimum'; end if;
  if v_ceiling is not null and v_score > v_ceiling then raise exception 'Starting score is above the configured maximum'; end if;

  insert into public.staff (staff_code, full_name, department, starting_score_tenths, current_score_tenths)
  values (trim(staff_code_input), trim(full_name_input), nullif(trim(coalesce(department_input, '')), ''), v_score, v_score)
  returning id into v_id;

  insert into public.merit_events (staff_id, actor_id, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason)
  values (v_id, v_actor, 'opening', v_score, null, v_score, 'Opening score');

  insert into public.audit_events (actor_id, action, target_type, target_id)
  values (v_actor, 'staff.create', 'staff', v_id);

  return v_id;
end;
$$;

create function public.adjust_merit(
  target_staff_id uuid,
  delta_tenths_input integer,
  reason_input text,
  request_id_input uuid
)
returns table (event_id uuid, score_before_tenths integer, score_after_tenths integer, was_replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_staff public.staff%rowtype;
  v_existing public.merit_events%rowtype;
  v_floor integer;
  v_ceiling integer;
  v_after integer;
  v_event_id uuid;
begin
  if v_actor is null or not public.has_permission('merit.adjust') then raise exception 'Not authorized'; end if;
  if request_id_input is null then raise exception 'Request identifier is required'; end if;
  if delta_tenths_input is null or abs(delta_tenths_input) not between 10 and 100 or abs(delta_tenths_input) % 10 <> 0 then
    raise exception 'Adjustment must be between 0.1 and 1.0 in 0.1 steps';
  end if;
  if length(trim(coalesce(reason_input, ''))) not between 1 and 500 then raise exception 'Reason is required (maximum 500 characters)'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_actor::text || request_id_input::text, 0)
  );

  select * into v_existing from public.merit_events e
  where e.actor_id = v_actor and e.request_id = request_id_input;
  if found then
    if v_existing.staff_id <> target_staff_id or v_existing.delta_tenths <> delta_tenths_input or v_existing.reason <> trim(reason_input) then
      raise exception 'Request identifier was already used for a different change';
    end if;
    return query select v_existing.id, v_existing.score_before_tenths, v_existing.score_after_tenths, true;
    return;
  end if;

  select * into v_staff from public.staff s where s.id = target_staff_id and not s.is_archived for update;
  if not found then raise exception 'Staff record was not found or is archived'; end if;

  select floor_tenths, ceiling_tenths into v_floor, v_ceiling
  from public.organization_settings where id = true;
  v_after := v_staff.current_score_tenths + delta_tenths_input;
  if v_floor is not null and v_after < v_floor then raise exception 'Adjustment is below the configured minimum'; end if;
  if v_ceiling is not null and v_after > v_ceiling then raise exception 'Adjustment is above the configured maximum'; end if;

  insert into public.merit_events (staff_id, actor_id, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason, request_id)
  values (target_staff_id, v_actor, 'adjustment', delta_tenths_input, v_staff.current_score_tenths, v_after, trim(reason_input), request_id_input)
  returning id into v_event_id;

  update public.staff set current_score_tenths = v_after, updated_at = now() where id = target_staff_id;
  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
  values (v_actor, 'merit.adjust', 'staff', target_staff_id, jsonb_build_object('event_id', v_event_id, 'delta_tenths', delta_tenths_input));

  return query select v_event_id, v_staff.current_score_tenths, v_after, false;
end;
$$;

alter table public.organization_settings enable row level security;
alter table public.staff enable row level security;
alter table public.profiles enable row level security;
alter table public.merit_events enable row level security;
alter table public.audit_events enable row level security;

create policy settings_read_authenticated on public.organization_settings
  for select to authenticated using (auth.uid() is not null);

create policy staff_read_scoped on public.staff
  for select to authenticated using (public.can_read_staff(id));

create policy profiles_read_self_or_owner on public.profiles
  for select to authenticated using (user_id = auth.uid() or public.has_permission('users.invite'));

create policy merit_read_scoped on public.merit_events
  for select to authenticated using (public.can_read_staff(staff_id));

create policy audit_read_owner on public.audit_events
  for select to authenticated using (public.has_permission('audit.read'));

grant usage on schema public to authenticated;
revoke all on public.organization_settings, public.staff, public.profiles, public.merit_events, public.audit_events from public, anon, authenticated;
grant select on public.organization_settings, public.staff, public.profiles, public.merit_events, public.audit_events to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.can_read_staff(uuid) to authenticated;
grant execute on function public.complete_password_setup() to authenticated;
grant execute on function public.create_staff(text, text, text, integer) to authenticated;
grant execute on function public.adjust_merit(uuid, integer, text, uuid) to authenticated;
revoke execute on function public.has_permission(text) from public, anon;
revoke execute on function public.can_read_staff(uuid) from public, anon;
revoke execute on function public.complete_password_setup() from public, anon;
revoke execute on function public.create_staff(text, text, text, integer) from public, anon;
revoke execute on function public.adjust_merit(uuid, integer, text, uuid) from public, anon;

comment on table public.staff is 'Private employee merit records; access is controlled by RLS.';
comment on table public.merit_events is 'Append-only merit ledger; changes are made through trusted database functions.';
