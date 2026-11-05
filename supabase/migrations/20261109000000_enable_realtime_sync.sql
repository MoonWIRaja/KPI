-- Migration: Enable Supabase Realtime publication for tables so phone and PC live-sync automatically

-- 1. Ensure supabase_realtime publication exists
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- 2. Add core data tables to supabase_realtime publication
alter publication supabase_realtime add table public.staff;
alter publication supabase_realtime add table public.merit_events;
alter publication supabase_realtime add table public.organization_settings;
alter publication supabase_realtime add table public.profiles;
