-- Migration: Grant CEO role identical Full Power permissions as Admin and Owner

-- 1. Update has_permission to treat CEO, Admin, and Owner as having identical full power
create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_active and not p.must_set_password and case
      when p.role in ('owner', 'admin', 'ceo') then true
      when p.role = 'staff' and $1 in ('account.read.self', 'merit.read.self') then true
      else false
    end
    from public.profiles p where p.user_id = auth.uid()
  ), false);
$$;

-- 2. Update assign_default_permissions so both CEO and Admin receive 100% full permissions
create or replace function public.assign_default_permissions()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.role in ('ceo', 'admin') then
    insert into public.user_permissions (user_id, permission_key) values
      (new.user_id, 'account.read.self'), (new.user_id, 'staff.read.all'),
      (new.user_id, 'staff.create'), (new.user_id, 'staff.update'),
      (new.user_id, 'staff.archive'), (new.user_id, 'staff.delete'),
      (new.user_id, 'staff.import'), (new.user_id, 'merit.read.all'),
      (new.user_id, 'merit.adjust'), (new.user_id, 'merit.correct'),
      (new.user_id, 'reports.read'), (new.user_id, 'reports.export'),
      (new.user_id, 'settings.manage'), (new.user_id, 'audit.read'),
      (new.user_id, 'users.manage'), (new.user_id, 'users.invite')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

-- 3. Backfill full permissions to any existing CEO profiles and ensure they are active
update public.profiles
set must_set_password = false,
    is_active = true
where role in ('ceo', 'admin');

insert into public.user_permissions (user_id, permission_key)
select p.user_id, c.permission_key
from public.profiles p
cross join public.permission_catalog c
where p.role in ('ceo', 'admin')
on conflict do nothing;
