-- Migration: Universal Admin Access & Guaranteed Staff Delete
-- 1. Ensure has_permission returns true for owner, admin, AND ceo for all permissions unconditionally
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

-- 2. Allow delete_staff and delete_staff_without_history to cleanly delete staff and cascading history
create or replace function public.delete_staff(target_staff_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_permission('staff.delete') then
    raise exception 'Not authorized to delete staff';
  end if;

  -- Unlink profile if linked
  update public.profiles set staff_id = null where staff_id = target_staff_id;

  -- Delete all merit events for this staff
  delete from public.merit_events where staff_id = target_staff_id;

  -- Delete staff record
  delete from public.staff where id = target_staff_id;

  insert into public.audit_events (actor_id, action, target_type, target_id)
    values (auth.uid(), 'staff.delete', 'staff', target_staff_id);
end;
$$;

grant execute on function public.delete_staff(uuid) to authenticated;
revoke execute on function public.delete_staff(uuid) from public, anon;

create or replace function public.delete_staff_without_history(target_staff_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.delete_staff(target_staff_id);
end;
$$;

grant execute on function public.delete_staff_without_history(uuid) to authenticated;
revoke execute on function public.delete_staff_without_history(uuid) from public, anon;

-- 3. Ensure all profiles with role in ('ceo', 'admin') are active, must_set_password false, and have all catalog permissions
update public.profiles
set is_active = true, must_set_password = false
where role in ('ceo', 'admin');

insert into public.user_permissions (user_id, permission_key)
select p.user_id, c.permission_key
from public.profiles p
cross join public.permission_catalog c
where p.role in ('ceo', 'admin')
on conflict do nothing;
