-- Zunivo v2. Execută în Supabase SQL Editor. Include migrarea versiunii anterioare.
create table if not exists public.user_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check (role in ('client','provider')),
 display_name text not null check (char_length(display_name) between 2 and 100),
 created_at timestamptz not null default now()
);
create table if not exists public.providers (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null unique references auth.users(id) on delete cascade,
 name text not null check (char_length(name) between 2 and 80),
 category text not null,
 county text not null,
 city text not null,
 phone text not null,
 description text not null check (char_length(description) <= 3000),
 created_at timestamptz not null default now()
);
alter table public.providers drop constraint if exists providers_description_check;
alter table public.providers add constraint providers_description_check check (char_length(description) <= 3000);
create table if not exists public.provider_services (
 id uuid primary key default gen_random_uuid(),
 provider_id uuid not null references public.providers(id) on delete cascade,
 title text not null check (char_length(title) between 2 and 120),
 details text not null default '' check (char_length(details) <= 1200),
 price numeric(12,2) not null check (price >= 0),
 price_unit text not null default 'serviciu' check (price_unit in ('serviciu','oră','eveniment','pachet','zi')),
 created_at timestamptz not null default now()
);
create index if not exists provider_services_provider_idx on public.provider_services(provider_id);
alter table public.user_profiles enable row level security;
alter table public.providers enable row level security;
alter table public.provider_services enable row level security;
-- Politici idempotente (pot fi rulate din nou).
drop policy if exists "Profiles own read" on public.user_profiles;
drop policy if exists "Profiles own insert" on public.user_profiles;
drop policy if exists "Profiles own update" on public.user_profiles;
create policy "Profiles own read" on public.user_profiles for select to authenticated using (auth.uid()=user_id);
create policy "Profiles own insert" on public.user_profiles for insert to authenticated with check (auth.uid()=user_id);
create policy "Profiles own update" on public.user_profiles for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id and role=(select role from public.user_profiles where user_id=auth.uid()));
drop policy if exists "Anyone can read providers" on public.providers;
drop policy if exists "Owners can create profiles" on public.providers;
drop policy if exists "Owners can edit profiles" on public.providers;
drop policy if exists "Owners can delete profiles" on public.providers;
create policy "Anyone can read providers" on public.providers for select to anon,authenticated using (true);
create policy "Owners can create profiles" on public.providers for insert to authenticated with check (auth.uid()=user_id and exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='provider'));
create policy "Owners can edit profiles" on public.providers for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Owners can delete profiles" on public.providers for delete to authenticated using (auth.uid()=user_id);
drop policy if exists "Public read services" on public.provider_services;
drop policy if exists "Provider add services" on public.provider_services;
drop policy if exists "Provider edit services" on public.provider_services;
drop policy if exists "Provider delete services" on public.provider_services;
create policy "Public read services" on public.provider_services for select to anon,authenticated using (true);
create policy "Provider add services" on public.provider_services for insert to authenticated with check (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
create policy "Provider edit services" on public.provider_services for update to authenticated using (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())) with check (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
create policy "Provider delete services" on public.provider_services for delete to authenticated using (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));


-- Zunivo V3: recenzii ale clienților (rulabil și peste V2)
create table if not exists public.provider_reviews (
 id uuid primary key default gen_random_uuid(),
 provider_id uuid not null references public.providers(id) on delete cascade,
 client_id uuid not null references auth.users(id) on delete cascade,
 rating integer not null check (rating between 1 and 5),
 comment text not null check (char_length(comment) between 10 and 2000),
 created_at timestamptz not null default now(),
 unique(provider_id,client_id)
);
create index if not exists provider_reviews_provider_idx on public.provider_reviews(provider_id);
alter table public.provider_reviews enable row level security;
drop policy if exists "Anyone can read reviews" on public.provider_reviews;
drop policy if exists "Clients can create reviews" on public.provider_reviews;
drop policy if exists "Clients can edit own reviews" on public.provider_reviews;
drop policy if exists "Clients can delete own reviews" on public.provider_reviews;
create policy "Anyone can read reviews" on public.provider_reviews for select to anon,authenticated using (true);
create policy "Clients can create reviews" on public.provider_reviews for insert to authenticated with check (
 client_id=auth.uid() and exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='client')
);
create policy "Clients can edit own reviews" on public.provider_reviews for update to authenticated using (
 client_id=auth.uid() and exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='client')
) with check (client_id=auth.uid() and exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='client'));
create policy "Clients can delete own reviews" on public.provider_reviews for delete to authenticated using (client_id=auth.uid());


-- ZUNIVO V5: rulează acest fișier în SQL Editor după ce ai făcut backup.
create table if not exists public.event_requests (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references auth.users(id) on delete cascade,
 category text not null, county text not null, event_date date not null,
 budget numeric(12,2) not null check(budget>=0), urgent boolean not null default false,
 details text not null check(char_length(details) between 15 and 1500),
 status text not null default 'open' check(status in ('open','assigned','closed')),
 created_at timestamptz not null default now()
);
create table if not exists public.event_offers (
 id uuid primary key default gen_random_uuid(), request_id uuid not null references public.event_requests(id) on delete cascade,
 provider_id uuid not null references public.providers(id) on delete cascade,
 price numeric(12,2) not null check(price>=0), message text not null check(char_length(message) between 10 and 1000),
 status text not null default 'pending' check(status in ('pending','accepted','confirmed','declined')),
 created_at timestamptz not null default now(),unique(request_id,provider_id)
);
create index if not exists event_offers_request_idx on public.event_offers(request_id);
create index if not exists event_requests_search_idx on public.event_requests(category,county,event_date);
alter table public.event_requests enable row level security;
alter table public.event_offers enable row level security;
drop policy if exists "Read event requests" on public.event_requests;
create policy "Read event requests" on public.event_requests for select to anon,authenticated using (true);
drop policy if exists "Client creates event request" on public.event_requests;
create policy "Client creates event request" on public.event_requests for insert to authenticated with check (
 client_id=auth.uid() and status='open' and event_date>=current_date and
 exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='client')
);
drop policy if exists "Relevant users read offers" on public.event_offers;
create policy "Relevant users read offers" on public.event_offers for select to authenticated using (
 exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())
 or exists(select 1 from public.event_requests r where r.id=request_id and r.client_id=auth.uid())
);
drop policy if exists "Providers submit offers" on public.event_offers;
create policy "Providers submit offers" on public.event_offers for insert to authenticated with check (
 status='pending' and exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())
 and exists(select 1 from public.event_requests r join public.providers p on p.id=provider_id where r.id=request_id and r.status='open' and r.category=p.category and r.county=p.county and r.client_id<>auth.uid())
);
-- Tranzițiile de stare se fac numai prin RPC, nu prin UPDATE direct.
create or replace function public.accept_event_offer(offer_uuid uuid) returns void language plpgsql security definer set search_path='' as $$
declare rid uuid;
begin
 select o.request_id into rid from public.event_offers o join public.event_requests r on r.id=o.request_id
 where o.id=offer_uuid and r.client_id=auth.uid() and r.status='open' and o.status='pending' for update of r;
 if rid is null then raise exception 'Oferta nu este disponibilă'; end if;
 update public.event_offers set status='declined' where request_id=rid and id<>offer_uuid and status='pending';
 update public.event_offers set status='accepted' where id=offer_uuid;
 update public.event_requests set status='assigned' where id=rid;
end $$;
create or replace function public.confirm_event_offer(offer_uuid uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 update public.event_offers o set status='confirmed'
 where o.id=offer_uuid and o.status='accepted'
 and exists(select 1 from public.providers p where p.id=o.provider_id and p.user_id=auth.uid());
 if not found then raise exception 'Nu poți confirma această ofertă'; end if;
end $$;
revoke all on function public.accept_event_offer(uuid) from public,anon;
revoke all on function public.confirm_event_offer(uuid) from public,anon;
grant execute on function public.accept_event_offer(uuid) to authenticated;
grant execute on function public.confirm_event_offer(uuid) to authenticated;


-- ZUNIVO V6: rulează DUPĂ V5. Nu elimina tabelele vechi.
create table if not exists public.guest_votes (
 id uuid primary key default gen_random_uuid(), provider_id uuid not null references public.providers(id) on delete cascade,
 client_id uuid not null references auth.users(id) on delete cascade,
 rating int not null check (rating between 1 and 5),
 event_label text not null default '' check (char_length(event_label)<=100),
 created_at timestamptz not null default now(), unique(provider_id,client_id)
);
alter table public.guest_votes enable row level security;
drop policy if exists "guest votes public" on public.guest_votes;
create policy "guest votes public" on public.guest_votes for select to anon,authenticated using (true);
drop policy if exists "client vote" on public.guest_votes;
create policy "client vote" on public.guest_votes for insert to authenticated with check (
 client_id=auth.uid() and exists(select 1 from public.user_profiles where user_id=auth.uid() and role='client'));
drop policy if exists "client edits vote" on public.guest_votes;
create policy "client edits vote" on public.guest_votes for update to authenticated using (client_id=auth.uid()) with check (client_id=auth.uid());
drop policy if exists "client deletes vote" on public.guest_votes;
create policy "client deletes vote" on public.guest_votes for delete to authenticated using (client_id=auth.uid());

create table if not exists public.duo_invites (
 id uuid primary key default gen_random_uuid(), from_provider uuid not null references public.providers(id) on delete cascade,
 to_provider uuid not null references public.providers(id) on delete cascade,
 title text not null check(char_length(title) between 4 and 120),
 description text not null default '' check(char_length(description)<=800),
 combined_price numeric(12,2) not null check(combined_price>=0),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(), check(from_provider<>to_provider),unique(from_provider,to_provider,title)
);
alter table public.duo_invites enable row level security;
drop policy if exists "duo visibility" on public.duo_invites;
create policy "duo visibility" on public.duo_invites for select to anon,authenticated using (
 status='accepted' or exists(select 1 from public.providers p where p.id=from_provider and p.user_id=auth.uid())
 or exists(select 1 from public.providers p where p.id=to_provider and p.user_id=auth.uid()));
drop policy if exists "duo proposal" on public.duo_invites;
create policy "duo proposal" on public.duo_invites for insert to authenticated with check (
 status='pending' and exists(select 1 from public.providers p where p.id=from_provider and p.user_id=auth.uid()));
-- Acceptare/refuz doar de către prestatorul invitat, prin funcție server-side.
create or replace function public.respond_duo(invite_uuid uuid, decision text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if decision not in ('accepted','declined') then raise exception 'Decizie invalidă'; end if;
 update public.duo_invites d set status=decision where d.id=invite_uuid and d.status='pending'
 and exists(select 1 from public.providers p where p.id=d.to_provider and p.user_id=auth.uid());
 if not found then raise exception 'Invitația nu poate fi modificată'; end if;
end $$;
revoke all on function public.respond_duo(uuid,text) from public,anon;
grant execute on function public.respond_duo(uuid,text) to authenticated;

create table if not exists public.econom_offers (
 id uuid primary key default gen_random_uuid(), provider_id uuid not null references public.providers(id) on delete cascade,
 title text not null check(char_length(title) between 4 and 120),
 original_price numeric(12,2) not null check(original_price>0),
 sale_price numeric(12,2) not null check(sale_price>=0 and sale_price<original_price),
 valid_from date not null, valid_to date not null, description text not null default '' check(char_length(description)<=700),
 created_at timestamptz not null default now(), check(valid_to>=valid_from)
);
alter table public.econom_offers enable row level security;
drop policy if exists "econom public" on public.econom_offers;
create policy "econom public" on public.econom_offers for select to anon,authenticated using (true);
drop policy if exists "econom insert" on public.econom_offers;
create policy "econom insert" on public.econom_offers for insert to authenticated with check (
 exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
drop policy if exists "econom delete" on public.econom_offers;
create policy "econom delete" on public.econom_offers for delete to authenticated using (
 exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));


-- ZUNIVO V7: rulează doar această secțiune dacă V6 este deja instalat.
create table if not exists public.service_progress (
 offer_id uuid primary key references public.event_offers(id) on delete cascade,
 stage text not null default 'În așteptare' check (stage in ('În așteptare','Pregătire','În desfășurare','În procesare','Livrat')),
 notes text not null default '' check(char_length(notes)<=1000), updated_at timestamptz not null default now()
);
alter table public.service_progress enable row level security;
drop policy if exists "progress participants read" on public.service_progress;
create policy "progress participants read" on public.service_progress for select to authenticated using (
 exists(select 1 from public.event_offers o join public.event_requests r on r.id=o.request_id join public.providers p on p.id=o.provider_id where o.id=offer_id and o.status='confirmed' and (r.client_id=auth.uid() or p.user_id=auth.uid())));
drop policy if exists "progress provider insert" on public.service_progress;
create policy "progress provider insert" on public.service_progress for insert to authenticated with check (
 exists(select 1 from public.event_offers o join public.providers p on p.id=o.provider_id where o.id=offer_id and o.status='confirmed' and p.user_id=auth.uid()));
drop policy if exists "progress provider update" on public.service_progress;
create policy "progress provider update" on public.service_progress for update to authenticated using (
 exists(select 1 from public.event_offers o join public.providers p on p.id=o.provider_id where o.id=offer_id and o.status='confirmed' and p.user_id=auth.uid())) with check (
 exists(select 1 from public.event_offers o join public.providers p on p.id=o.provider_id where o.id=offer_id and o.status='confirmed' and p.user_id=auth.uid()));

create table if not exists public.radar_preferences (
 provider_id uuid primary key references public.providers(id) on delete cascade,
 category text not null, county text not null, min_budget numeric(12,2) not null default 0 check(min_budget>=0), updated_at timestamptz not null default now()
);
alter table public.radar_preferences enable row level security;
drop policy if exists "radar owner read" on public.radar_preferences;
create policy "radar owner read" on public.radar_preferences for select to authenticated using (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
drop policy if exists "radar owner insert" on public.radar_preferences;
create policy "radar owner insert" on public.radar_preferences for insert to authenticated with check (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
drop policy if exists "radar owner update" on public.radar_preferences;
create policy "radar owner update" on public.radar_preferences for update to authenticated using (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())) with check (exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));

create table if not exists public.backup_proposals (
 id uuid primary key default gen_random_uuid(), offer_id uuid not null references public.event_offers(id) on delete cascade,
 backup_provider_id uuid not null references public.providers(id) on delete cascade,
 reason text not null check(char_length(reason) between 10 and 700),
 status text not null default 'pending' check(status in ('pending','accepted_by_backup','declined_by_backup','approved_by_client','rejected_by_client')),
 created_at timestamptz not null default now(), unique(offer_id,backup_provider_id)
);
alter table public.backup_proposals enable row level security;
drop policy if exists "backup participants read" on public.backup_proposals;
create policy "backup participants read" on public.backup_proposals for select to authenticated using (
 exists(select 1 from public.providers p where p.id=backup_provider_id and p.user_id=auth.uid())
 or exists(select 1 from public.event_offers o join public.providers p on p.id=o.provider_id join public.event_requests r on r.id=o.request_id where o.id=offer_id and (p.user_id=auth.uid() or r.client_id=auth.uid())));
drop policy if exists "backup original provider insert" on public.backup_proposals;
create policy "backup original provider insert" on public.backup_proposals for insert to authenticated with check (
 status='pending' and exists(select 1 from public.event_offers o join public.providers p on p.id=o.provider_id join public.providers b on b.id=backup_provider_id join public.event_requests r on r.id=o.request_id where o.id=offer_id and o.status='confirmed' and p.user_id=auth.uid() and b.id<>p.id and b.category=r.category));
create or replace function public.respond_backup(proposal_uuid uuid,decision text)
returns void language plpgsql security definer set search_path='' as $$
declare row_data record;
begin
 select b.id,b.status,b.backup_provider_id,r.client_id into row_data
 from public.backup_proposals b join public.event_offers o on o.id=b.offer_id join public.event_requests r on r.id=o.request_id
 where b.id=proposal_uuid for update of b;
 if not found then raise exception 'Invitația nu există'; end if;
 if decision in ('backup_accept','backup_decline') then
  if row_data.status<>'pending' or not exists(select 1 from public.providers p where p.id=row_data.backup_provider_id and p.user_id=auth.uid()) then raise exception 'Nu poți răspunde acestei invitații'; end if;
  update public.backup_proposals set status=case when decision='backup_accept' then 'accepted_by_backup' else 'declined_by_backup' end where id=proposal_uuid;
 elsif decision in ('client_approve','client_reject') then
  if row_data.status<>'accepted_by_backup' or row_data.client_id<>auth.uid() then raise exception 'Clientul nu poate aproba această propunere'; end if;
  update public.backup_proposals set status=case when decision='client_approve' then 'approved_by_client' else 'rejected_by_client' end where id=proposal_uuid;
 else raise exception 'Decizie invalidă'; end if;
end $$;
revoke all on function public.respond_backup(uuid,text) from public,anon;
grant execute on function public.respond_backup(uuid,text) to authenticated;


-- ZUNIVO V8: rulează această secțiune după instalarea V7.
-- VERIFIED: doar administratorul cu acces la SQL Editor poate adăuga/șterge verificări.
create table if not exists public.verified_providers (
 provider_id uuid primary key references public.providers(id) on delete cascade,
 verified_at timestamptz not null default now(),
 note text not null default '' check(char_length(note)<=500)
);
alter table public.verified_providers enable row level security;
drop policy if exists "verified public read" on public.verified_providers;
create policy "verified public read" on public.verified_providers for select to anon,authenticated using (true);
-- Exemplu pentru administrator, executat NUMAI după verificarea documentelor:
-- insert into public.verified_providers(provider_id) values ('UUID_PRESTATOR');

-- MEET: clientul solicită; prestatorul răspunde prin RPC validat pe server.
create table if not exists public.meet_requests (
 id uuid primary key default gen_random_uuid(),
 client_id uuid not null references auth.users(id) on delete cascade,
 provider_id uuid not null references public.providers(id) on delete cascade,
 requested_at timestamptz not null,
 message text not null check(char_length(message) between 5 and 600),
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 meeting_url text check(meeting_url is null or (char_length(meeting_url)<=500 and meeting_url ~ '^https://[^[:space:]]+$')),
 created_at timestamptz not null default now()
);
create index if not exists meet_client_idx on public.meet_requests(client_id);
create index if not exists meet_provider_idx on public.meet_requests(provider_id);
alter table public.meet_requests enable row level security;
drop policy if exists "meet participants read" on public.meet_requests;
create policy "meet participants read" on public.meet_requests for select to authenticated using (
 client_id=auth.uid() or exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
drop policy if exists "meet client create" on public.meet_requests;
create policy "meet client create" on public.meet_requests for insert to authenticated with check (
 client_id=auth.uid() and status='pending' and meeting_url is null and requested_at>now()
 and exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='client'));
create or replace function public.respond_meet(request_uuid uuid,decision text,link_url text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if decision not in ('accepted','declined') then raise exception 'Decizie invalidă'; end if;
 if decision='accepted' and (link_url is null or char_length(link_url)>500 or link_url !~ '^https://[^[:space:]]+$') then raise exception 'Link HTTPS invalid'; end if;
 update public.meet_requests m set status=decision,meeting_url=case when decision='accepted' then link_url else null end
 where m.id=request_uuid and m.status='pending'
 and exists(select 1 from public.providers p where p.id=m.provider_id and p.user_id=auth.uid());
 if not found then raise exception 'Nu poți modifica această întâlnire'; end if;
end $$;
revoke all on function public.respond_meet(uuid,text,text) from public,anon;
grant execute on function public.respond_meet(uuid,text,text) to authenticated;

-- REWARDS: coduri de recomandare, fără plăți sau premii automate.
create table if not exists public.referral_codes (
 user_id uuid primary key references auth.users(id) on delete cascade,
 code text not null unique check(code ~ '^[A-F0-9]{10}$'),
 created_at timestamptz not null default now()
);
create table if not exists public.referral_claims (
 id uuid primary key default gen_random_uuid(),
 referrer_user uuid not null references auth.users(id) on delete cascade,
 referred_user uuid not null unique references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 check(referrer_user<>referred_user)
);
alter table public.referral_codes enable row level security;
alter table public.referral_claims enable row level security;
drop policy if exists "claim own read" on public.referral_claims;
create policy "claim own read" on public.referral_claims for select to authenticated using (referred_user=auth.uid());
create or replace function public.get_my_referral_code()
returns text language plpgsql security definer set search_path='' as $$
declare result text;
begin
 if auth.uid() is null or not exists(select 1 from public.user_profiles where user_id=auth.uid() and role='client') then raise exception 'Doar pentru clienți'; end if;
 insert into public.referral_codes(user_id,code) values(auth.uid(),upper(substr(md5(auth.uid()::text),1,10))) on conflict(user_id) do nothing;
 select code into result from public.referral_codes where user_id=auth.uid();
 return result;
end $$;
create or replace function public.claim_referral(ref_code text)
returns void language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.user_profiles where user_id=auth.uid() and role='client') then raise exception 'Doar pentru clienți'; end if;
 select user_id into owner_id from public.referral_codes where code=upper(trim(ref_code));
 if owner_id is null or owner_id=auth.uid() then raise exception 'Cod invalid sau propriu'; end if;
 insert into public.referral_claims(referrer_user,referred_user) values(owner_id,auth.uid());
end $$;
revoke all on function public.get_my_referral_code() from public,anon;
revoke all on function public.claim_referral(text) from public,anon;
grant execute on function public.get_my_referral_code() to authenticated;
grant execute on function public.claim_referral(text) to authenticated;

-- ZUNIVO V9: execută doar această secțiune la upgrade de la V8.
-- INVITE: accesul la invitație se face prin token aleator; nu publica linkul fără acord.
create table if not exists public.digital_invites (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 token uuid not null unique default gen_random_uuid(), title text not null check(char_length(title) between 3 and 100),
 event_date date not null, venue text not null check(char_length(venue) between 2 and 150),
 description text not null default '' check(char_length(description)<=1000),
 created_at timestamptz not null default now()
);
create table if not exists public.invite_rsvps (
 id uuid primary key default gen_random_uuid(), invite_id uuid not null references public.digital_invites(id) on delete cascade,
 guest_name text not null check(char_length(guest_name) between 2 and 80), answer text not null check(answer in ('yes','no')),
 party_size integer not null check(party_size between 1 and 10), created_at timestamptz not null default now()
);
alter table public.digital_invites enable row level security;
alter table public.invite_rsvps enable row level security;
create policy "v9 invite owner read" on public.digital_invites for select to authenticated using(owner_id=auth.uid());
create policy "v9 invite owner create" on public.digital_invites for insert to authenticated with check(owner_id=auth.uid() and exists(select 1 from public.user_profiles u where u.user_id=auth.uid() and u.role='client'));
create policy "v9 rsvp owner read" on public.invite_rsvps for select to authenticated using(exists(select 1 from public.digital_invites i where i.id=invite_id and i.owner_id=auth.uid()));
create or replace function public.v9_invite_public(t uuid)
returns table(title text,event_date date,venue text,description text)
language sql security definer set search_path='' as $$
 select i.title,i.event_date,i.venue,i.description from public.digital_invites i where i.token=t;
$$;
create or replace function public.v9_rsvp(t uuid,guest text,reply text,people integer)
returns void language plpgsql security definer set search_path='' as $$
declare iid uuid;
begin
 if char_length(trim(guest)) not between 2 and 80 or reply not in ('yes','no') or people not between 1 and 10 then raise exception 'Date RSVP invalide'; end if;
 select id into iid from public.digital_invites where token=t and event_date>=current_date;
 if iid is null then raise exception 'Invitație invalidă sau eveniment încheiat'; end if;
 insert into public.invite_rsvps(invite_id,guest_name,answer,party_size) values(iid,trim(guest),reply,people);
end $$;
revoke all on function public.v9_invite_public(uuid) from public;
revoke all on function public.v9_rsvp(uuid,text,text,integer) from public;
grant execute on function public.v9_invite_public(uuid) to anon,authenticated;
grant execute on function public.v9_rsvp(uuid,text,text,integer) to anon,authenticated;

-- INSIGHTS: număr aproximativ de vizite, actualizat doar prin RPC; fără IP stocat.
create table if not exists public.provider_views (
 provider_id uuid primary key references public.providers(id) on delete cascade,
 total_views bigint not null default 0 check(total_views>=0)
);
alter table public.provider_views enable row level security;
create or replace function public.v9_record_view(pid uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.providers where id=pid) then
 insert into public.provider_views(provider_id,total_views) values(pid,1)
 on conflict(provider_id) do update set total_views=public.provider_views.total_views+1;
 end if;
end $$;
revoke all on function public.v9_record_view(uuid) from public;
grant execute on function public.v9_record_view(uuid) to anon,authenticated;

-- TEAM: codurile se citesc numai de proprietar, aderarea se face prin RPC.
create table if not exists public.team_invite_codes (
 id uuid primary key default gen_random_uuid(),provider_id uuid not null references public.providers(id) on delete cascade,
 code uuid not null unique default gen_random_uuid(),expires_at timestamptz not null default(now()+interval '7 days'),
 created_at timestamptz not null default now()
);
create table if not exists public.team_members (
 provider_id uuid not null references public.providers(id) on delete cascade,
 member_id uuid not null references auth.users(id) on delete cascade,
 joined_at timestamptz not null default now(),primary key(provider_id,member_id)
);
alter table public.team_invite_codes enable row level security;
alter table public.team_members enable row level security;
create policy "v9 team codes owner" on public.team_invite_codes for select to authenticated using(exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
create policy "v9 team members read" on public.team_members for select to authenticated using(member_id=auth.uid() or exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
create or replace function public.v9_new_team_code(pid uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare c uuid;
begin
 if not exists(select 1 from public.providers p where p.id=pid and p.user_id=auth.uid()) then raise exception 'Nu ești proprietarul profilului'; end if;
 insert into public.team_invite_codes(provider_id) values(pid) returning code into c;
 return c;
end $$;
create or replace function public.v9_join_team(c uuid)
returns void language plpgsql security definer set search_path='' as $$
declare pid uuid;
begin
 if auth.uid() is null then raise exception 'Autentificare necesară'; end if;
 select provider_id into pid from public.team_invite_codes where code=c and expires_at>now();
 if pid is null then raise exception 'Cod expirat sau invalid'; end if;
 if exists(select 1 from public.providers where id=pid and user_id=auth.uid()) then raise exception 'Ești deja proprietarul'; end if;
 insert into public.team_members(provider_id,member_id) values(pid,auth.uid()) on conflict do nothing;
 delete from public.team_invite_codes where code=c;
end $$;
create or replace function public.v9_leave_team(pid uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 delete from public.team_members where provider_id=pid and member_id=auth.uid();
end $$;
create or replace function public.v9_remove_team_member(pid uuid,mid uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.providers where id=pid and user_id=auth.uid()) then raise exception 'Acces interzis'; end if;
 delete from public.team_members where provider_id=pid and member_id=mid;
end $$;
create or replace function public.v9_my_insights()
returns table(provider_id uuid,provider_name text,views bigint,services bigint,offers bigint)
language sql security definer set search_path='' as $$
 select p.id,p.name,coalesce(v.total_views,0),
 (select count(*) from public.provider_services s where s.provider_id=p.id),
 (select count(*) from public.event_offers o where o.provider_id=p.id)
 from public.providers p left join public.provider_views v on v.provider_id=p.id
 where p.user_id=auth.uid() or exists(select 1 from public.team_members m where m.provider_id=p.id and m.member_id=auth.uid());
$$;
revoke all on function public.v9_new_team_code(uuid) from public;
revoke all on function public.v9_join_team(uuid) from public;
revoke all on function public.v9_leave_team(uuid) from public;
revoke all on function public.v9_remove_team_member(uuid,uuid) from public;
revoke all on function public.v9_my_insights() from public;
grant execute on function public.v9_new_team_code(uuid),public.v9_join_team(uuid),public.v9_leave_team(uuid),public.v9_remove_team_member(uuid,uuid),public.v9_my_insights() to authenticated;

-- NOTIFY: notificări persistente în cont; fără push/email.
create table if not exists public.user_notifications (
 id uuid primary key default gen_random_uuid(),recipient_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(char_length(title)<=140),body text not null default '' check(char_length(body)<=500),
 href text not null default 'dashboard.html',read_at timestamptz,created_at timestamptz not null default now()
);
create index if not exists v9_notifications_user_idx on public.user_notifications(recipient_id,created_at desc);
alter table public.user_notifications enable row level security;
create policy "v9 own notifications read" on public.user_notifications for select to authenticated using(recipient_id=auth.uid());
create or replace function public.v9_mark_notification(nid uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 update public.user_notifications set read_at=now() where recipient_id=auth.uid() and read_at is null and (nid is null or id=nid);
end $$;
revoke all on function public.v9_mark_notification(uuid) from public,anon;
grant execute on function public.v9_mark_notification(uuid) to authenticated;
create or replace function public.v9_notify_meet() returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 if tg_op='INSERT' then
  select user_id into target from public.providers where id=new.provider_id;
  if target is not null then insert into public.user_notifications(recipient_id,title,body,href) values(target,'Întâlnire nouă','Ai primit o solicitare Zunivo Meet.','meet.html'); end if;
 elsif new.status is distinct from old.status then
  insert into public.user_notifications(recipient_id,title,body,href) values(new.client_id,'Răspuns la întâlnire','Prestatorul a răspuns la solicitarea ta.','meet.html');
 end if;
 return new;
end $$;
drop trigger if exists v9_meet_notice on public.meet_requests;
create trigger v9_meet_notice after insert or update of status on public.meet_requests for each row execute function public.v9_notify_meet();
create or replace function public.v9_notify_offer() returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 if tg_op='INSERT' then
  select client_id into target from public.event_requests where id=new.request_id;
  if target is not null then insert into public.user_notifications(recipient_id,title,body,href) values(target,'Ofertă nouă','Ai primit o ofertă pentru cererea ta.','cereri.html'); end if;
 elsif new.status is distinct from old.status then
  select user_id into target from public.providers where id=new.provider_id;
  if target is not null then insert into public.user_notifications(recipient_id,title,body,href) values(target,'Status ofertă schimbat','O ofertă a primit un status nou.','cereri.html'); end if;
 end if;
 return new;
end $$;
drop trigger if exists v9_offer_notice on public.event_offers;
create trigger v9_offer_notice after insert or update of status on public.event_offers for each row execute function public.v9_notify_offer();


-- ZUNIVO V10: evaluari private ale clientilor de catre prestatori.
-- Ruleaza DOAR aceasta sectiune la upgrade de la V9.
create table if not exists public.client_reviews (
 offer_id uuid primary key references public.event_offers(id) on delete cascade,
 provider_id uuid not null references public.providers(id) on delete cascade,
 client_id uuid not null references auth.users(id) on delete cascade,
 rating smallint not null check (rating between 1 and 5),
 communication smallint not null check (communication between 1 and 5),
 punctuality smallint not null check (punctuality between 1 and 5),
 agreement smallint not null check (agreement between 1 and 5),
 comment text not null check (char_length(comment) between 10 and 1000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists client_reviews_client_idx on public.client_reviews(client_id);
alter table public.client_reviews enable row level security;
drop policy if exists "v10 parties read client review" on public.client_reviews;
create policy "v10 parties read client review" on public.client_reviews for select to authenticated using (
 client_id=auth.uid() or exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())
);
drop policy if exists "v10 provider creates client review" on public.client_reviews;
create policy "v10 provider creates client review" on public.client_reviews for insert to authenticated with check (
 exists(select 1 from public.event_offers o join public.event_requests r on r.id=o.request_id join public.providers p on p.id=o.provider_id
 where o.id=offer_id and o.status='confirmed' and o.provider_id=client_reviews.provider_id and r.client_id=client_reviews.client_id and p.user_id=auth.uid())
);
drop policy if exists "v10 provider edits client review" on public.client_reviews;
create policy "v10 provider edits client review" on public.client_reviews for update to authenticated using (
 exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())
) with check (
 exists(select 1 from public.event_offers o join public.event_requests r on r.id=o.request_id join public.providers p on p.id=o.provider_id
 where o.id=offer_id and o.status='confirmed' and o.provider_id=client_reviews.provider_id and r.client_id=client_reviews.client_id and p.user_id=auth.uid())
);
drop policy if exists "v10 provider deletes client review" on public.client_reviews;
create policy "v10 provider deletes client review" on public.client_reviews for delete to authenticated using (
 exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())
);


-- ZUNIVO V11: ADMIN SECURIZAT. Executa doar aceasta sectiune la upgrade de la V10.
-- IMPORTANT: Nu stoca parola administratorului in SQL, JS sau HTML.
-- 1) Creeaza manual un cont Supabase Auth cu email propriu si parola privata.
-- 2) Gaseste UUID-ul utilizatorului in Authentication > Users.
-- 3) Executa: INSERT INTO public.zunivo_admins(user_id,username) VALUES ('UUID-REAL'::uuid,'contactfotoparausergiu@gmail.com');
-- Nu crea acest cont prin formularul public de inregistrare.
create table if not exists public.zunivo_admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check (username ~ '^[a-zA-Z0-9_@.+-]+$'),
 created_at timestamptz not null default now()
);
-- Permite adrese de email drept identificator administrativ inclusiv pe instalari vechi.
do $$ declare c record; begin
 for c in select conname from pg_catalog.pg_constraint
 where conrelid='public.zunivo_admins'::regclass and contype='c' loop
   if pg_catalog.pg_get_constraintdef((select oid from pg_catalog.pg_constraint where conrelid='public.zunivo_admins'::regclass and conname=c.conname)) like '%username%' then
     execute format('alter table public.zunivo_admins drop constraint %I',c.conname);
   end if;
 end loop;
end $$;
alter table public.zunivo_admins add constraint zunivo_admin_username_valid check (username ~ '^[a-zA-Z0-9_@.+-]+$');
alter table public.zunivo_admins enable row level security;
revoke all on public.zunivo_admins from anon, authenticated;
create table if not exists public.zunivo_admin_audit (
 id bigint generated always as identity primary key,
 admin_id uuid not null references auth.users(id),
 table_name text not null, operation text not null, record_key text,
 before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
alter table public.zunivo_admin_audit enable row level security;
revoke all on public.zunivo_admin_audit from anon,authenticated;

create or replace function public.zunivo_admin_api(
 p_action text, p_table text default null, p_key text default null,
 p_data jsonb default '{}'::jsonb, p_limit integer default 30, p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_allowed constant text[] := array['user_profiles','providers','provider_services','provider_reviews','event_requests','event_offers','guest_votes','duo_invites','econom_offers','service_progress','radar_preferences','backup_proposals','verified_providers','meet_requests','referral_codes','referral_claims','digital_invites','invite_rsvps','provider_views','team_invite_codes','team_members','user_notifications','client_reviews','restaurant_details'];
 v_pk text; v_result jsonb; v_before jsonb; v_after jsonb;
 v_cols text; v_updates text; v_name text; v_count bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.zunivo_admins where user_id=auth.uid()) then
   raise exception 'Acces administrator interzis' using errcode='42501';
 end if;
 if p_action='catalog' then
   return (select coalesce(jsonb_agg(t order by t),'[]'::jsonb) from unnest(v_allowed) t);
 end if;
 if p_action='audit' then
   return (select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at desc),'[]'::jsonb)
     from (select * from public.zunivo_admin_audit order by created_at desc limit 100) a);
 end if;
 if p_table is null or not (p_table=any(v_allowed)) then raise exception 'Tabel nepermis'; end if;
 select a.attname into v_pk from pg_catalog.pg_index i
 join pg_catalog.pg_attribute a on a.attrelid=i.indrelid and a.attnum=any(i.indkey)
 where i.indrelid=pg_catalog.to_regclass(format('public.%I',p_table)) and i.indisprimary limit 1;
 if v_pk is null then raise exception 'Cheie primara lipsa'; end if;
 if p_action='list' then
   execute format('select count(*) from public.%I',p_table) into v_count;
   execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from (select * from public.%I order by %I::text desc limit $1 offset $2) x',p_table,v_pk)
    into v_result using least(greatest(coalesce(p_limit,30),1),100),greatest(coalesce(p_offset,0),0);
   return jsonb_build_object('pk',v_pk,'total',v_count,'rows',coalesce(v_result,'[]'::jsonb));
 end if;
 if p_action not in ('insert','update','delete') then raise exception 'Actiune necunoscuta'; end if;
 if p_action in ('update','delete') and (p_key is null or length(p_key)>256) then raise exception 'Cheie invalida'; end if;
 if p_action in ('update','delete') then
   execute format('select to_jsonb(t) from public.%I t where %I::text=$1',p_table,v_pk) into v_before using p_key;
   if v_before is null then raise exception 'Inregistrare inexistenta'; end if;
 end if;
 if p_action='delete' then
   execute format('delete from public.%I where %I::text=$1',p_table,v_pk) using p_key;
 elsif p_action='insert' then
   if jsonb_typeof(p_data) <> 'object' then raise exception 'Date JSON invalide'; end if;
   execute format('insert into public.%I select (jsonb_populate_record(null::public.%I,$1)).* returning to_jsonb(%I)',p_table,p_table,p_table)
      into v_after using p_data;
 else
   if jsonb_typeof(p_data) <> 'object' then raise exception 'Date JSON invalide'; end if;
   select string_agg(format('%I=(jsonb_populate_record(null::public.%I,$1)).%I',k,p_table,k),', ')
     into v_updates from jsonb_object_keys(p_data) k
     where k<>v_pk and exists (select 1 from information_schema.columns c where c.table_schema='public' and c.table_name=p_table and c.column_name=k and c.is_generated='NEVER');
   if v_updates is null then raise exception 'Nicio coloana editabila'; end if;
   execute format('update public.%I set %s where %I::text=$2 returning to_jsonb(%I)',p_table,v_updates,v_pk,p_table)
      into v_after using p_data,p_key;
 end if;
 insert into public.zunivo_admin_audit(admin_id,table_name,operation,record_key,before_data,after_data)
 values(auth.uid(),p_table,p_action,coalesce(p_key, v_after->>v_pk),v_before,v_after);
 return jsonb_build_object('ok',true,'row',v_after);
end $$;
revoke all on function public.zunivo_admin_api(text,text,text,jsonb,integer,integer) from public,anon;
grant execute on function public.zunivo_admin_api(text,text,text,jsonb,integer,integer) to authenticated;

-- ZUNIVO V12: restaurante si sali de evenimente (executa separat daca ai deja V11)
create table if not exists public.restaurant_details (
 provider_id uuid primary key references public.providers(id) on delete cascade,
 address text not null default '' check (char_length(address)<=250),
 capacity_min integer check (capacity_min is null or capacity_min>=0),
 capacity_max integer check (capacity_max is null or capacity_max>0),
 menu_price_min numeric(12,2) check (menu_price_min is null or menu_price_min>=0),
 menu_price_max numeric(12,2) check (menu_price_max is null or menu_price_max>=0),
 hall_rental_price numeric(12,2) check (hall_rental_price is null or hall_rental_price>=0),
 cuisine text not null default '' check (char_length(cuisine)<=160),
 website text not null default '' check (char_length(website)<=350),
 event_types text not null default '' check (char_length(event_types)<=350),
 facilities text not null default '' check (char_length(facilities)<=700),
 menu_details text not null default '' check (char_length(menu_details)<=3000),
 updated_at timestamptz not null default now(),
 constraint restaurant_capacity_order check(capacity_min is null or capacity_max is null or capacity_min<=capacity_max),
 constraint restaurant_menu_order check(menu_price_min is null or menu_price_max is null or menu_price_min<=menu_price_max)
);
alter table public.restaurant_details enable row level security;
drop policy if exists "Restaurant public read" on public.restaurant_details;
drop policy if exists "Restaurant owner insert" on public.restaurant_details;
drop policy if exists "Restaurant owner update" on public.restaurant_details;
drop policy if exists "Restaurant owner delete" on public.restaurant_details;
create policy "Restaurant public read" on public.restaurant_details for select to anon,authenticated using(true);
create policy "Restaurant owner insert" on public.restaurant_details for insert to authenticated with check(exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid() and p.category='Restaurante & săli de evenimente'));
create policy "Restaurant owner update" on public.restaurant_details for update to authenticated using(exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid())) with check(exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid() and p.category='Restaurante & săli de evenimente'));
create policy "Restaurant owner delete" on public.restaurant_details for delete to authenticated using(exists(select 1 from public.providers p where p.id=provider_id and p.user_id=auth.uid()));
