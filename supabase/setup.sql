-- Gloop: database setup for Supabase.
-- Paste this whole file into Supabase → SQL Editor → New query, and press Run.
-- It's safe to run again.

-- 1. Profiles: one row per account with the name your crew sees and your invite code.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default 'Gloop friend',
  referral_code text unique not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- You can read and edit only your own profile. (Crew-sharing rules come later.)
drop policy if exists "Read own profile" on public.profiles;
create policy "Read own profile" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "Update own profile" on public.profiles;
create policy "Update own profile" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- 2. Invite codes like ALEX-K6MN: first name plus four random characters.
create or replace function public.make_referral_code(person_name text)
returns text
language plpgsql
as $$
declare
  base text := upper(left(regexp_replace(split_part(coalesce(person_name, ''), ' ', 1), '[^A-Za-z]', '', 'g'), 6));
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  if base = '' then base := 'GLOOP'; end if;
  loop
    code := base || '-';
    for i in 1..4 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where referral_code = code);
  end loop;
  return code;
end;
$$;

-- 3. Make a profile automatically for every new account (email, Google or Apple).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  person_name text := coalesce(
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    'Gloop friend');
begin
  insert into public.profiles (id, name, referral_code)
  values (new.id, person_name, public.make_referral_code(person_name))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Let people delete their own account from Settings.
create or replace function public.delete_my_account()
returns void
language sql
security definer set search_path = public
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
