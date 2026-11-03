create table public.initial_owner_setup (
  id boolean primary key default true check (id),
  expected_email text,
  claimed_user_id uuid references auth.users (id) on delete restrict,
  claimed_at timestamptz,
  check ((claimed_user_id is null) = (claimed_at is null))
);

insert into public.initial_owner_setup (id) values (true)
on conflict (id) do nothing;

alter table public.initial_owner_setup enable row level security;
revoke all on public.initial_owner_setup from public, anon, authenticated;

update public.initial_owner_setup s
set expected_email = lower(trim(p.email)),
    claimed_user_id = p.user_id,
    claimed_at = coalesce(s.claimed_at, now())
from public.profiles p
where s.id = true and p.role = 'owner';

create function public.can_claim_initial_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(exists (
    select 1
    from public.initial_owner_setup s
    join auth.users u on u.id = auth.uid()
    where s.id = true
      and s.expected_email is not null
      and s.claimed_at is null
      and lower(u.email) = s.expected_email
      and u.email_confirmed_at is not null
      and not exists (select 1 from public.profiles p where p.role = 'owner')
  ), false);
$$;

create function public.bootstrap_initial_owner(display_name_input text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_email text;
  v_expected_email text;
  v_claimed_at timestamptz;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(display_name_input, ''))) not between 1 and 160 then
    raise exception 'Name must contain 1 to 160 characters';
  end if;

  select expected_email, claimed_at
    into v_expected_email, v_claimed_at
    from public.initial_owner_setup where id = true for update;
  select lower(email) into v_email from auth.users
    where id = v_actor and email_confirmed_at is not null;

  if v_expected_email is null or v_claimed_at is not null or v_email is distinct from v_expected_email
     or exists (select 1 from public.profiles where role = 'owner') then
    raise exception 'Initial Owner setup is not available for this account';
  end if;

  insert into public.profiles (user_id, email, display_name, role, staff_id, is_active, must_set_password)
    values (v_actor, v_email, trim(display_name_input), 'owner', null, true, false);

  update public.initial_owner_setup
    set claimed_user_id = v_actor, claimed_at = now()
    where id = true and claimed_at is null;
  if not found then raise exception 'Initial Owner setup has already been claimed'; end if;

  insert into public.audit_events (actor_id, action, target_type, target_id)
    values (v_actor, 'owner.bootstrap', 'profile', v_actor);
end;
$$;

grant execute on function public.can_claim_initial_owner() to authenticated;
grant execute on function public.bootstrap_initial_owner(text) to authenticated;
revoke execute on function public.can_claim_initial_owner() from public, anon;
revoke execute on function public.bootstrap_initial_owner(text) from public, anon;
