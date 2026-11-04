-- Allow direct deletion of staff records by authorized users.
-- Unlinks any profile linked to this staff, deletes all associated merit_events,
-- and removes the staff record.

create or replace function public.delete_staff(target_staff_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('staff.delete') then
    raise exception 'Not authorized';
  end if;

  -- Unlink profile if linked
  update public.profiles set staff_id = null where staff_id = target_staff_id;

  -- Delete all merit events for this staff
  delete from public.merit_events where staff_id = target_staff_id;

  -- Delete staff record
  delete from public.staff where id = target_staff_id;
  if not found then
    raise exception 'Staff record was not found';
  end if;

  insert into public.audit_events (actor_id, action, target_type, target_id)
    values (auth.uid(), 'staff.delete', 'staff', target_staff_id);
end;
$$;

grant execute on function public.delete_staff(uuid) to authenticated;
revoke execute on function public.delete_staff(uuid) from public, anon;

-- Update delete_staff_without_history to also allow direct deletion
create or replace function public.delete_staff_without_history(target_staff_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.delete_staff(target_staff_id);
end;
$$;

grant execute on function public.delete_staff_without_history(uuid) to authenticated;
revoke execute on function public.delete_staff_without_history(uuid) from public, anon;
