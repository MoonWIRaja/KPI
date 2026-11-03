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

create table public.permission_catalog (
  permission_key text primary key,
  label text not null,
  role_assignable boolean not null default true
);

insert into public.permission_catalog (permission_key, label, role_assignable) values
  ('account.read.self', 'Lihat profil sendiri', false),
  ('merit.read.self', 'Lihat merit sendiri', false),
  ('staff.read.all', 'Lihat semua rekod staff', true),
  ('staff.create', 'Tambah rekod staff', true),
  ('staff.update', 'Edit rekod staff', true),
  ('staff.archive', 'Arkib/pulihkan staff', true),
  ('staff.delete', 'Padam staff tanpa sejarah merit', true),
  ('staff.import', 'Import CSV staff', true),
  ('merit.read.all', 'Lihat semua aktiviti merit', true),
  ('merit.adjust', 'Tambah/kurang merit', true),
  ('merit.correct', 'Buat pembetulan merit', true),
  ('reports.read', 'Lihat laporan', true),
  ('reports.export', 'Eksport laporan', true),
  ('settings.manage', 'Ubah tetapan merit', true),
  ('audit.read', 'Lihat audit sistem', true),
  ('users.manage', 'Urus akaun dan kebenaran', false),
  ('users.invite', 'Jemput pengguna', false)
on conflict (permission_key) do nothing;

create table public.user_permissions (
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  permission_key text not null references public.permission_catalog (permission_key) on delete cascade,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users (id) on delete set null,
  primary key (user_id, permission_key)
);

create function public.assign_default_permissions()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.role = 'ceo' then
    insert into public.user_permissions (user_id, permission_key) values
      (new.user_id, 'account.read.self'), (new.user_id, 'staff.read.all'),
      (new.user_id, 'staff.create'), (new.user_id, 'staff.update'),
      (new.user_id, 'staff.archive'), (new.user_id, 'staff.import'),
      (new.user_id, 'merit.read.all'), (new.user_id, 'merit.adjust'),
      (new.user_id, 'merit.correct'), (new.user_id, 'reports.read'),
      (new.user_id, 'reports.export'), (new.user_id, 'settings.manage'),
      (new.user_id, 'audit.read');
  elsif new.role = 'staff' then
    insert into public.user_permissions (user_id, permission_key) values
      (new.user_id, 'account.read.self'), (new.user_id, 'merit.read.self');
  end if;
  return new;
end;
$$;

create trigger profiles_assign_permissions after insert on public.profiles
  for each row execute function public.assign_default_permissions();

create table public.merit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  staff_id uuid not null references public.staff (id) on delete restrict,
  actor_id uuid references auth.users (id) on delete set null,
  actor_display_name text,
  event_type text not null check (event_type in ('opening', 'adjustment', 'correction')),
  delta_tenths bigint not null,
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
    select p.is_active and not p.must_set_password and case
      when p.role = 'owner' then auth.jwt() ->> 'aal' = 'aal2'
      when p.role = 'ceo' and $1 not in ('users.manage', 'users.invite')
        then auth.jwt() ->> 'aal' = 'aal2' and exists (
          select 1 from public.user_permissions up
          where up.user_id = p.user_id and up.permission_key = $1
        )
      when p.role = 'staff' and $1 in ('account.read.self', 'merit.read.self') then true
      when p.role = 'staff' and $1 not in ('users.manage', 'users.invite')
        then auth.jwt() ->> 'aal' = 'aal2' and exists (
          select 1 from public.user_permissions up
          where up.user_id = p.user_id and up.permission_key = $1
        )
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
  select public.has_permission('staff.read.all') or (public.has_permission('merit.read.self') and exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.is_active and p.role = 'staff' and p.staff_id = target_staff_id
  ));
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
  where user_id = v_actor and is_active = true and must_set_password = true;
  if not found then raise exception 'Password setup is not pending'; end if;
  insert into public.audit_events (actor_id, action, target_type, target_id)
  values (v_actor, 'account.password_set', 'profile', v_actor);
end;
$$;

create function public.create_staff(
  staff_code_input text,
  full_name_input text,
  department_input text default null,
  starting_score_tenths_input bigint default null
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
  if v_actor is null or not (public.has_permission('staff.create') or public.has_permission('staff.import')) then raise exception 'Not authorized'; end if;
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

  insert into public.merit_events (staff_id, actor_id, actor_display_name, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason)
  values (v_id, v_actor, (select display_name from public.profiles where user_id = v_actor), 'opening', v_score, null, v_score, 'Opening score');

  insert into public.audit_events (actor_id, action, target_type, target_id)
  values (v_actor, 'staff.create', 'staff', v_id);

  return v_id;
end;
$$;

create function public.update_staff(target_staff_id uuid, staff_code_input text, full_name_input text, department_input text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('staff.update') then raise exception 'Not authorized'; end if;
  if length(trim(coalesce(staff_code_input, ''))) not between 1 and 40 or length(trim(coalesce(full_name_input, ''))) not between 1 and 160 then
    raise exception 'Staff code and name are required';
  end if;
  update public.staff set staff_code = trim(staff_code_input), full_name = trim(full_name_input),
    department = nullif(trim(coalesce(department_input, '')), ''), updated_at = now()
    where id = target_staff_id;
  if not found then raise exception 'Staff record was not found'; end if;
  insert into public.audit_events (actor_id, action, target_type, target_id)
    values (auth.uid(), 'staff.update', 'staff', target_staff_id);
end;
$$;

create function public.set_staff_archived(target_staff_id uuid, archived_input boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('staff.archive') then raise exception 'Not authorized'; end if;
  update public.staff set is_archived = archived_input, updated_at = now() where id = target_staff_id;
  if not found then raise exception 'Staff record was not found'; end if;
  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
    values (auth.uid(), case when archived_input then 'staff.archive' else 'staff.restore' end, 'staff', target_staff_id, jsonb_build_object('archived', archived_input));
end;
$$;

create function public.delete_staff_without_history(target_staff_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('staff.delete') then raise exception 'Not authorized'; end if;
  if exists (select 1 from public.profiles where staff_id = target_staff_id) then raise exception 'Staff account is linked; deactivate account and archive this record instead'; end if;
  if exists (select 1 from public.merit_events where staff_id = target_staff_id) then raise exception 'Staff record has merit history; archive it instead of deleting'; end if;
  delete from public.staff where id = target_staff_id;
  if not found then raise exception 'Staff record was not found'; end if;
  insert into public.audit_events (actor_id, action, target_type, target_id)
    values (auth.uid(), 'staff.delete', 'staff', target_staff_id);
end;
$$;

create function public.import_staff(rows_input jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_row jsonb;
  v_count integer := 0;
begin
  if auth.uid() is null or not public.has_permission('staff.import') then raise exception 'Not authorized'; end if;
  if rows_input is null or jsonb_typeof(rows_input) <> 'array' then raise exception 'CSV import payload must be a JSON array'; end if;
  if jsonb_array_length(rows_input) = 0 or jsonb_array_length(rows_input) > 500 then raise exception 'CSV import must contain between 1 and 500 staff rows'; end if;
  for v_row in select value from jsonb_array_elements(rows_input) loop
    if length(trim(coalesce(v_row->>'staff_code', ''))) not between 1 and 40
       or length(trim(coalesce(v_row->>'full_name', ''))) not between 1 and 160
       or coalesce(v_row->>'starting_score_tenths', '') !~ '^-?[0-9]{1,15}$' then
      raise exception 'CSV contains a staff row with invalid code, name or starting merit';
    end if;
  end loop;
  if exists (
    select lower(trim(value->>'staff_code')) from jsonb_array_elements(rows_input)
    group by lower(trim(value->>'staff_code')) having count(*) > 1
  ) then raise exception 'CSV contains duplicate staff codes'; end if;
  for v_row in select value from jsonb_array_elements(rows_input) loop
    perform public.create_staff(v_row->>'staff_code', v_row->>'full_name', v_row->>'department', (v_row->>'starting_score_tenths')::bigint);
    v_count := v_count + 1;
  end loop;
  insert into public.audit_events (actor_id, action, target_type, metadata)
    values (auth.uid(), 'staff.import', 'staff', jsonb_build_object('rows', v_count));
  return v_count;
end;
$$;

create function public.update_organization_settings(default_score_input bigint, floor_input bigint, ceiling_input bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('settings.manage') then raise exception 'Not authorized'; end if;
  if floor_input is not null and ceiling_input is not null and floor_input > ceiling_input then raise exception 'Minimum merit cannot exceed maximum merit'; end if;
  if floor_input is not null and default_score_input < floor_input then raise exception 'Default merit is below the configured minimum'; end if;
  if ceiling_input is not null and default_score_input > ceiling_input then raise exception 'Default merit is above the configured maximum'; end if;
  if floor_input is not null and exists (select 1 from public.staff where current_score_tenths < floor_input) then raise exception 'Existing staff scores are below the new minimum'; end if;
  if ceiling_input is not null and exists (select 1 from public.staff where current_score_tenths > ceiling_input) then raise exception 'Existing staff scores are above the new maximum'; end if;
  update public.organization_settings set default_starting_score_tenths = default_score_input, floor_tenths = floor_input,
    ceiling_tenths = ceiling_input, updated_at = now() where id = true;
  insert into public.audit_events (actor_id, action, target_type, metadata)
    values (auth.uid(), 'settings.update', 'organization_settings', jsonb_build_object('default_tenths', default_score_input, 'has_floor', floor_input is not null, 'has_ceiling', ceiling_input is not null));
end;
$$;

create function public.set_user_permissions(target_user_id uuid, permission_keys_input text[])
returns void language plpgsql security definer set search_path = '' as $$
declare v_role text;
begin
  if auth.uid() is null or not public.has_permission('users.manage') then raise exception 'Not authorized'; end if;
  select role into v_role from public.profiles where user_id = target_user_id and is_active = true;
  if v_role is null or v_role = 'owner' then raise exception 'Target account cannot be changed'; end if;
  if exists (
    select 1 from unnest(coalesce(permission_keys_input, array[]::text[])) requested(key)
    left join public.permission_catalog c on c.permission_key = requested.key
    where c.permission_key is null or not c.role_assignable
  ) then raise exception 'Permission list contains an invalid or protected permission'; end if;
  delete from public.user_permissions where user_id = target_user_id;
  insert into public.user_permissions (user_id, permission_key, granted_by)
    select target_user_id, requested.permission_key, auth.uid()
    from unnest(coalesce(permission_keys_input, array[]::text[])) as requested(permission_key);
  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
    values (auth.uid(), 'user.permissions.update', 'profile', target_user_id, jsonb_build_object('permission_count', cardinality(permission_keys_input)));
end;
$$;

create function public.set_user_active(target_user_id uuid, active_input boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_role text;
begin
  if auth.uid() is null or not public.has_permission('users.manage') then raise exception 'Not authorized'; end if;
  select role into v_role from public.profiles where user_id = target_user_id;
  if v_role is null or v_role = 'owner' or target_user_id = auth.uid() then raise exception 'Target account cannot be changed'; end if;
  update public.profiles set is_active = active_input where user_id = target_user_id;
  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
    values (auth.uid(), case when active_input then 'user.activate' else 'user.deactivate' end, 'profile', target_user_id, jsonb_build_object('active', active_input));
end;
$$;

create function public.record_report_export(from_input timestamptz, to_input timestamptz, rows_input integer)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('reports.export') then raise exception 'Not authorized'; end if;
  insert into public.audit_events (actor_id, action, target_type, metadata)
    values (auth.uid(), 'report.export', 'merit_events', jsonb_build_object('from', from_input, 'to', to_input, 'rows', greatest(rows_input, 0)));
end;
$$;

create or replace function public.complete_password_setup()
returns void language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  update public.profiles set must_set_password = false
  where user_id = v_actor and is_active = true and must_set_password = true;
  if not found then raise exception 'Password setup is not pending'; end if;
  insert into public.audit_events (actor_id, action, target_type, target_id)
  values (v_actor, 'account.password_set', 'profile', v_actor);
end;
$$;

create function public.adjust_merit(
  target_staff_id uuid,
  delta_tenths_input integer,
  reason_input text,
  request_id_input uuid
)
returns table (event_id uuid, score_before_tenths bigint, score_after_tenths bigint, was_replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_staff public.staff%rowtype;
  v_existing public.merit_events%rowtype;
  v_floor bigint;
  v_ceiling bigint;
  v_after bigint;
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

  insert into public.merit_events (staff_id, actor_id, actor_display_name, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason, request_id)
  values (target_staff_id, v_actor, (select display_name from public.profiles where user_id = v_actor), 'adjustment', delta_tenths_input, v_staff.current_score_tenths, v_after, trim(reason_input), request_id_input)
  returning id into v_event_id;

  update public.staff set current_score_tenths = v_after, updated_at = now() where id = target_staff_id;
  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
  values (v_actor, 'merit.adjust', 'staff', target_staff_id, jsonb_build_object('event_id', v_event_id, 'delta_tenths', delta_tenths_input));

  return query select v_event_id, v_staff.current_score_tenths, v_after, false;
end;
$$;

create function public.correct_merit(target_staff_id uuid, new_score_tenths bigint, reason_input text, request_id_input uuid)
returns table (event_id uuid, score_before_tenths bigint, score_after_tenths bigint)
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_staff public.staff%rowtype;
  v_existing public.merit_events%rowtype;
  v_event_id uuid;
  v_floor bigint;
  v_ceiling bigint;
begin
  if v_actor is null or not public.has_permission('merit.correct') then raise exception 'Not authorized'; end if;
  if request_id_input is null then raise exception 'Request identifier is required'; end if;
  if length(trim(coalesce(reason_input, ''))) not between 1 and 500 then raise exception 'Reason is required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_actor::text || request_id_input::text, 0));
  select * into v_existing from public.merit_events where actor_id = v_actor and request_id = request_id_input;
  if found then
    if v_existing.staff_id <> target_staff_id or v_existing.event_type <> 'correction' or v_existing.score_after_tenths <> new_score_tenths or v_existing.reason <> trim(reason_input) then
      raise exception 'Request identifier was already used for a different correction';
    end if;
    return query select v_existing.id, v_existing.score_before_tenths, v_existing.score_after_tenths;
    return;
  end if;
  select * into v_staff from public.staff where id = target_staff_id and not is_archived for update;
  if not found then raise exception 'Staff record was not found or is archived'; end if;
  select floor_tenths, ceiling_tenths into v_floor, v_ceiling from public.organization_settings where id = true;
  if v_floor is not null and new_score_tenths < v_floor then raise exception 'Correction is below the configured minimum'; end if;
  if v_ceiling is not null and new_score_tenths > v_ceiling then raise exception 'Correction is above the configured maximum'; end if;
  insert into public.merit_events (staff_id, actor_id, actor_display_name, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason, request_id)
    values (target_staff_id, v_actor, (select display_name from public.profiles where user_id = v_actor), 'correction', new_score_tenths - v_staff.current_score_tenths, v_staff.current_score_tenths, new_score_tenths, trim(reason_input), request_id_input)
    returning id into v_event_id;
  update public.staff set current_score_tenths = new_score_tenths, updated_at = now() where id = target_staff_id;
  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
    values (v_actor, 'merit.correct', 'staff', target_staff_id, jsonb_build_object('event_id', v_event_id));
  return query select v_event_id, v_staff.current_score_tenths, new_score_tenths;
end;
$$;

alter table public.organization_settings enable row level security;
alter table public.staff enable row level security;
alter table public.profiles enable row level security;
alter table public.permission_catalog enable row level security;
alter table public.user_permissions enable row level security;
alter table public.merit_events enable row level security;
alter table public.audit_events enable row level security;

create policy settings_read_authenticated on public.organization_settings
  for select to authenticated using (public.has_permission('account.read.self') or public.has_permission('settings.manage'));

create policy staff_read_scoped on public.staff
  for select to authenticated using (public.can_read_staff(id));

create policy profiles_read_self_or_owner on public.profiles
  for select to authenticated using ((user_id = auth.uid() and is_active = true) or public.has_permission('users.manage'));

create policy permission_catalog_read_authenticated on public.permission_catalog
  for select to authenticated using (public.has_permission('account.read.self'));

create policy user_permissions_read_scoped on public.user_permissions
  for select to authenticated using (public.has_permission('account.read.self') and (user_id = auth.uid() or public.has_permission('users.manage')));

create policy merit_read_scoped on public.merit_events
  for select to authenticated using (
    public.has_permission('merit.read.all') or (
      public.has_permission('merit.read.self') and exists (
        select 1 from public.profiles p
        where p.user_id = auth.uid() and p.role = 'staff' and p.is_active = true and p.staff_id = merit_events.staff_id
      )
    )
  );

create policy audit_read_owner on public.audit_events
  for select to authenticated using (public.has_permission('audit.read'));

grant usage on schema public to authenticated;
revoke all on public.organization_settings, public.staff, public.profiles, public.permission_catalog, public.user_permissions, public.merit_events, public.audit_events from public, anon, authenticated;
grant select on public.organization_settings, public.staff, public.profiles, public.permission_catalog, public.user_permissions, public.merit_events, public.audit_events to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.can_read_staff(uuid) to authenticated;
grant execute on function public.complete_password_setup() to authenticated;
grant execute on function public.create_staff(text, text, text, bigint) to authenticated;
grant execute on function public.adjust_merit(uuid, integer, text, uuid) to authenticated;
grant execute on function public.correct_merit(uuid, bigint, text, uuid) to authenticated;
grant execute on function public.update_staff(uuid, text, text, text) to authenticated;
grant execute on function public.set_staff_archived(uuid, boolean) to authenticated;
grant execute on function public.delete_staff_without_history(uuid) to authenticated;
grant execute on function public.import_staff(jsonb) to authenticated;
grant execute on function public.update_organization_settings(bigint, bigint, bigint) to authenticated;
grant execute on function public.set_user_permissions(uuid, text[]) to authenticated;
grant execute on function public.set_user_active(uuid, boolean) to authenticated;
grant execute on function public.record_report_export(timestamptz, timestamptz, integer) to authenticated;
revoke execute on function public.has_permission(text) from public, anon;
revoke execute on function public.can_read_staff(uuid) from public, anon;
revoke execute on function public.complete_password_setup() from public, anon;
revoke execute on function public.create_staff(text, text, text, bigint) from public, anon;
revoke execute on function public.adjust_merit(uuid, integer, text, uuid) from public, anon;
revoke execute on function public.correct_merit(uuid, bigint, text, uuid) from public, anon;
revoke execute on function public.update_staff(uuid, text, text, text) from public, anon;
revoke execute on function public.set_staff_archived(uuid, boolean) from public, anon;
revoke execute on function public.delete_staff_without_history(uuid) from public, anon;
revoke execute on function public.import_staff(jsonb) from public, anon;
revoke execute on function public.update_organization_settings(bigint, bigint, bigint) from public, anon;
revoke execute on function public.set_user_permissions(uuid, text[]) from public, anon;
revoke execute on function public.set_user_active(uuid, boolean) from public, anon;
revoke execute on function public.record_report_export(timestamptz, timestamptz, integer) from public, anon;
revoke execute on function public.assign_default_permissions() from public, anon, authenticated;

comment on table public.staff is 'Private employee merit records; access is controlled by RLS.';
comment on table public.merit_events is 'Append-only merit ledger; changes are made through trusted database functions.';
