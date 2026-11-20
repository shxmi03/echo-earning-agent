-- Landing page waitlist (https://handspan.vercel.app).
-- Anyone may add an email; nobody can read, change or delete rows through the API.
-- Read the list in the dashboard or with the service role.

create table public.waitlist (
  id         bigint generated always as identity primary key,
  email      text not null,
  source     text not null default 'landing',
  created_at timestamptz not null default now(),
  constraint waitlist_email_format check (
    char_length(email) between 3 and 254
    and email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  constraint waitlist_source_len check (char_length(source) <= 40)
);

-- One row per address, whatever the case.
create unique index waitlist_email_key on public.waitlist (lower(email));

alter table public.waitlist enable row level security;

revoke all on public.waitlist from anon, authenticated;
grant insert (email, source) on public.waitlist to anon, authenticated;

create policy "anyone can join the waitlist"
  on public.waitlist for insert
  to anon, authenticated
  with check (true);
