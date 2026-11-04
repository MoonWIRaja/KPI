-- Add organization_name and score_unit to organization_settings
alter table public.organization_settings
  add column if not exists organization_name text not null default 'MESRC DEVICE',
  add column if not exists score_unit text not null default 'merit';

-- Enhanced update function
create or replace function public.update_organization_settings_v2(
  default_score_input bigint,
  floor_input bigint,
  ceiling_input bigint,
  org_name_input text default 'MESRC DEVICE',
  score_unit_input text default 'merit'
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission('settings.manage') then
    raise exception 'Not authorized';
  end if;

  if floor_input is not null and ceiling_input is not null and floor_input > ceiling_input then
    raise exception 'The minimum score cannot exceed the maximum.';
  end if;

  if floor_input is not null and default_score_input < floor_input then
    raise exception 'The default score must be at or above the minimum.';
  end if;

  if ceiling_input is not null and default_score_input > ceiling_input then
    raise exception 'The default score must be at or below the maximum.';
  end if;

  update public.organization_settings
  set default_starting_score_tenths = default_score_input,
      floor_tenths = floor_input,
      ceiling_tenths = ceiling_input,
      organization_name = coalesce(nullif(trim(org_name_input), ''), 'MESRC DEVICE'),
      score_unit = coalesce(nullif(trim(score_unit_input), ''), 'merit'),
      updated_at = now()
  where id = true;

  insert into public.audit_events (actor_id, action, target_type, target_id, details)
    values (
      auth.uid(),
      'settings.update',
      'organization_settings',
      null,
      jsonb_build_object(
        'default_tenths', default_score_input,
        'has_floor', floor_input is not null,
        'has_ceiling', ceiling_input is not null,
        'organization_name', org_name_input,
        'score_unit', score_unit_input
      )
    );
end;
$$;

grant execute on function public.update_organization_settings_v2(bigint, bigint, bigint, text, text) to authenticated;
revoke execute on function public.update_organization_settings_v2(bigint, bigint, bigint, text, text) from public, anon;
