-- Mes consommations : schéma Supabase
-- À coller une fois dans Supabase → SQL Editor → Run.
-- Les données sont publiques en lecture ; chacun n'écrit que ses propres lignes.

-- ---------- Relevés saisis à la main ----------
create table if not exists public.releves (
  id            bigint generated always as identity primary key,
  user_id       uuid not null default auth.uid() references auth.users on delete cascade,
  categorie     text not null check (categorie in ('electricite', 'carburant', 'gaz')),
  date          date not null default current_date,
  valeur        numeric,   -- électricité : index du compteur (kWh) · carburant : compteur kilométrique
  litres        numeric,   -- carburant
  euros         numeric,   -- carburant, gaz
  kg            numeric,   -- gaz
  plein_complet boolean,   -- carburant : réservoir rempli à ras
  lieu          text,
  note          text,
  photo         text,      -- chemin du fichier dans le bucket « photos »
  created_at    timestamptz not null default now()
);
create index if not exists releves_user_date on public.releves (user_id, categorie, date);

-- ---------- Jauges Claude (remplies par le collecteur) ----------
create table if not exists public.claude_usage (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references auth.users on delete cascade,
  ts               timestamptz not null default now(),
  session_5h       numeric,
  session_5h_reset timestamptz,
  semaine          numeric,
  semaine_reset    timestamptz
);
create index if not exists claude_usage_user_ts on public.claude_usage (user_id, ts);

-- ---------- Clés du collecteur (jamais lisibles depuis le site) ----------
create table if not exists public.cles_collecteur (
  user_id    uuid primary key references auth.users on delete cascade,
  cle        text not null unique,
  created_at timestamptz not null default now()
);

-- ---------- Droits ----------
alter table public.releves         enable row level security;
alter table public.claude_usage    enable row level security;
alter table public.cles_collecteur enable row level security;

drop policy if exists "lecture publique" on public.releves;
drop policy if exists "ajout perso"      on public.releves;
drop policy if exists "modif perso"      on public.releves;
drop policy if exists "suppr perso"      on public.releves;
create policy "lecture publique" on public.releves for select to anon, authenticated using (true);
create policy "ajout perso"      on public.releves for insert to authenticated with check (user_id = auth.uid());
create policy "modif perso"      on public.releves for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "suppr perso"      on public.releves for delete to authenticated using (user_id = auth.uid());

drop policy if exists "lecture publique" on public.claude_usage;
create policy "lecture publique" on public.claude_usage for select to anon, authenticated using (true);
-- pas de politique sur cles_collecteur : table invisible depuis l'API

-- Le site connecté génère (ou remplace) la clé de son collecteur.
create or replace function public.nouvelle_cle_collecteur()
returns text language plpgsql security definer set search_path = public as $$
declare
  k text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if auth.uid() is null then raise exception 'connexion requise'; end if;
  insert into cles_collecteur (user_id, cle) values (auth.uid(), k)
    on conflict (user_id) do update set cle = excluded.cle, created_at = now();
  return k;
end $$;
revoke execute on function public.nouvelle_cle_collecteur() from public, anon;
grant execute on function public.nouvelle_cle_collecteur() to authenticated;

-- Le collecteur envoie un relevé avec sa clé, sans compte connecté.
create or replace function public.ajouter_releve_claude(
  p_cle text, p_session_5h numeric, p_session_5h_reset timestamptz,
  p_semaine numeric, p_semaine_reset timestamptz)
returns void language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  select user_id into uid from cles_collecteur where cle = p_cle;
  if uid is null then raise exception 'clé collecteur inconnue'; end if;
  insert into claude_usage (user_id, session_5h, session_5h_reset, semaine, semaine_reset)
    values (uid, p_session_5h, p_session_5h_reset, p_semaine, p_semaine_reset);
end $$;
revoke execute on function public.ajouter_releve_claude(text, numeric, timestamptz, numeric, timestamptz) from public;
grant execute on function public.ajouter_releve_claude(text, numeric, timestamptz, numeric, timestamptz) to anon, authenticated;

-- ---------- Photos ----------
insert into storage.buckets (id, name, public) values ('photos', 'photos', true)
  on conflict (id) do nothing;

drop policy if exists "photos lecture" on storage.objects;
drop policy if exists "photos ajout"   on storage.objects;
drop policy if exists "photos suppr"   on storage.objects;
create policy "photos lecture" on storage.objects for select to anon, authenticated
  using (bucket_id = 'photos');
create policy "photos ajout" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos suppr" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
