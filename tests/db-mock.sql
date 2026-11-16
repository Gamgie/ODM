-- Imitation minimale de Supabase : rôles, auth.uid(), stockage.
create role anon nologin; create role authenticated nologin;
create schema auth; create table auth.users(id uuid primary key, created_at timestamptz default now());
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.uid', true),'')::uuid $$;
create schema storage; create table storage.buckets(id text primary key, name text, public bool);
create table storage.objects(id serial, bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql as $$ select string_to_array(name,'/') $$;
grant usage on schema public, auth, storage to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'), ('22222222-2222-2222-2222-222222222222');
