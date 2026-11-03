-- Expose only the one-time setup state so the unauthenticated app can choose
-- between its first-run screen and the normal sign-in screen.
create or replace function public.is_initial_owner_setup_complete()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.initial_owner_setup s
      where s.id = true and s.claimed_at is not null
    )
    or exists (
      select 1 from public.profiles p where p.role = 'owner'
    ),
    false
  );
$$;

revoke all on function public.is_initial_owner_setup_complete() from public;
grant execute on function public.is_initial_owner_setup_complete() to anon, authenticated;
