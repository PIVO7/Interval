-- Self-service account deletion (App Store Review Guideline 5.1.1(v)).
--
-- A client using the anon/publishable key cannot delete a row from
-- auth.users — that needs elevated privileges. This SECURITY DEFINER
-- function runs as its owner (postgres), deletes the calling user's data
-- and their auth record, and is the only thing the client is allowed to
-- invoke. It always acts on auth.uid(), so a user can only ever delete
-- their own account.

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Remove user-owned data first. (If these tables have ON DELETE CASCADE
  -- FKs to auth.users the auth.users delete below would cover them too,
  -- but deleting explicitly keeps this correct regardless of FK setup.)
  delete from public.workouts where user_id = uid;
  delete from public.user_preferences where user_id = uid;

  -- Finally delete the auth user itself. This invalidates the session.
  delete from auth.users where id = uid;
end;
$$;

-- Only authenticated users may call it; never anon/public.
revoke all on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;
