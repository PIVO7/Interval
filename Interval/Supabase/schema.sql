-- Interval — Supabase schema
--
-- Run this in Supabase SQL Editor (Project → SQL Editor → New query).
-- Designed for the standard `public` schema with Row Level Security (RLS) on.
--
-- Tables:
--   workouts            — saved favorite interval schemas, one row per favorite
--   user_preferences    — per-user audio/haptic preferences (one row per user)
--
-- Auth provider: Apple via Supabase Auth (signInWithIdToken)
-- The `auth.users` table is managed by Supabase itself; we reference it by uuid.

----------------------------------------------------------------------
-- workouts
----------------------------------------------------------------------
create table if not exists public.workouts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  work_seconds    integer not null check (work_seconds between 5 and 3600),
  rest_seconds    integer not null check (rest_seconds between 0 and 3600),
  rounds          integer not null check (rounds between 1 and 99),
  created_at      timestamptz not null default now()
);

create index if not exists workouts_user_id_idx on public.workouts(user_id);
create index if not exists workouts_created_at_idx on public.workouts(created_at desc);

alter table public.workouts enable row level security;

drop policy if exists "Users read their own workouts" on public.workouts;
create policy "Users read their own workouts"
  on public.workouts for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert their own workouts" on public.workouts;
create policy "Users insert their own workouts"
  on public.workouts for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update their own workouts" on public.workouts;
create policy "Users update their own workouts"
  on public.workouts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete their own workouts" on public.workouts;
create policy "Users delete their own workouts"
  on public.workouts for delete
  using (auth.uid() = user_id);

----------------------------------------------------------------------
-- user_preferences
----------------------------------------------------------------------
create table if not exists public.user_preferences (
  user_id                 uuid primary key references auth.users(id) on delete cascade,
  default_sound           text not null default 'none',
  sound_volume            real not null default 0.5 check (sound_volume between 0 and 1),
  signal_tones_enabled    boolean not null default true,
  haptics_enabled         boolean not null default true,
  language_override       text,
  updated_at              timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

drop policy if exists "Users read their own preferences" on public.user_preferences;
create policy "Users read their own preferences"
  on public.user_preferences for select
  using (auth.uid() = user_id);

drop policy if exists "Users upsert their own preferences" on public.user_preferences;
create policy "Users upsert their own preferences"
  on public.user_preferences for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update their own preferences" on public.user_preferences;
create policy "Users update their own preferences"
  on public.user_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

----------------------------------------------------------------------
-- updated_at trigger for user_preferences
----------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists user_preferences_set_updated_at on public.user_preferences;
create trigger user_preferences_set_updated_at
  before update on public.user_preferences
  for each row execute function public.set_updated_at();
