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

-- ---------- Clés du collecteur : une par appareil (jamais lisibles depuis le site) ----------
create table if not exists public.cles_collecteur (
  cle            text primary key,
  user_id        uuid not null references auth.users on delete cascade,
  appareil       text not null default 'ordinateur',
  created_at     timestamptz not null default now(),
  dernier_releve timestamptz
);
-- Migration depuis la version « une clé par compte » (clé primaire sur user_id)
alter table public.cles_collecteur add column if not exists appareil text not null default 'ordinateur';
alter table public.cles_collecteur add column if not exists dernier_releve timestamptz;
do $$ begin
  if exists (select 1 from information_schema.key_column_usage
             where table_schema = 'public' and table_name = 'cles_collecteur'
               and constraint_name = 'cles_collecteur_pkey' and column_name = 'user_id') then
    alter table public.cles_collecteur drop constraint cles_collecteur_pkey;
    alter table public.cles_collecteur add primary key (cle);
  end if;
end $$;
create unique index if not exists cles_collecteur_appareil on public.cles_collecteur (user_id, appareil);
alter table public.claude_usage add column if not exists appareil text;

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

-- Le site connecté génère (ou remplace) la clé d'un de ses appareils.
drop function if exists public.nouvelle_cle_collecteur();
create or replace function public.nouvelle_cle_collecteur(p_appareil text)
returns text language plpgsql security definer set search_path = public as $$
declare
  k text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  nom text := coalesce(nullif(left(trim(p_appareil), 40), ''), 'ordinateur');
begin
  if auth.uid() is null then raise exception 'connexion requise'; end if;
  insert into cles_collecteur (user_id, appareil, cle) values (auth.uid(), nom, k)
    on conflict (user_id, appareil) do update set cle = excluded.cle, created_at = now(), dernier_releve = null;
  return k;
end $$;
revoke execute on function public.nouvelle_cle_collecteur(text) from public, anon;
grant execute on function public.nouvelle_cle_collecteur(text) to authenticated;

-- Liste des appareils du compte connecté (sans les clés).
create or replace function public.mes_collecteurs()
returns table (appareil text, created_at timestamptz, dernier_releve timestamptz)
language sql security definer set search_path = public stable as $$
  select appareil, created_at, dernier_releve from cles_collecteur
  where user_id = auth.uid() order by appareil;
$$;
revoke execute on function public.mes_collecteurs() from public, anon;
grant execute on function public.mes_collecteurs() to authenticated;

create or replace function public.supprimer_collecteur(p_appareil text)
returns void language sql security definer set search_path = public as $$
  delete from cles_collecteur where user_id = auth.uid() and appareil = p_appareil;
$$;
revoke execute on function public.supprimer_collecteur(text) from public, anon;
grant execute on function public.supprimer_collecteur(text) to authenticated;

-- Le collecteur envoie un relevé avec sa clé, sans compte connecté.
-- Les jauges sont celles du compte : si un autre appareil a déjà relevé il y a moins
-- de 10 minutes, le relevé est ignoré (deux ordinateurs allumés = pas de doublons).
drop function if exists public.ajouter_releve_claude(text, numeric, timestamptz, numeric, timestamptz);
create or replace function public.ajouter_releve_claude(
  p_cle text, p_session_5h numeric, p_session_5h_reset timestamptz,
  p_semaine numeric, p_semaine_reset timestamptz)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid; nom text;
begin
  select user_id, appareil into uid, nom from cles_collecteur where cle = p_cle;
  if uid is null then raise exception 'clé collecteur inconnue'; end if;
  update cles_collecteur set dernier_releve = now() where cle = p_cle;
  if exists (select 1 from claude_usage where user_id = uid and ts > now() - interval '10 minutes') then
    return 'ignoré : relevé récent d''un autre appareil';
  end if;
  insert into claude_usage (user_id, appareil, session_5h, session_5h_reset, semaine, semaine_reset)
    values (uid, nom, p_session_5h, p_session_5h_reset, p_semaine, p_semaine_reset);
  return 'enregistré';
end $$;
revoke execute on function public.ajouter_releve_claude(text, numeric, timestamptz, numeric, timestamptz) from public;
grant execute on function public.ajouter_releve_claude(text, numeric, timestamptz, numeric, timestamptz) to anon, authenticated;

-- ---------- Photos : non conservées ----------
-- Les photos sont lues par la fonction « lire-photo » puis oubliées.
-- Nettoyage de la première version, qui les stockait :
alter table public.releves drop column if exists photo;
drop policy if exists "photos lecture" on storage.objects;
drop policy if exists "photos ajout"   on storage.objects;
drop policy if exists "photos suppr"   on storage.objects;
