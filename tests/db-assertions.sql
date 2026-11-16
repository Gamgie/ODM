-- Chaque bloc échoue (et arrête le script) si une règle n'est pas respectée.
\o /dev/null
create function pg_temp.verifier(ok bool, quoi text) returns void language plpgsql as $$
begin if not coalesce(ok, false) then raise exception 'ÉCHEC : %', quoi; end if; end $$;
create function pg_temp.doit_echouer(sql text, quoi text) returns void language plpgsql as $$
begin execute sql; raise exception 'ÉCHEC : % aurait dû être refusé', quoi;
exception when others then if sqlerrm like 'ÉCHEC%' then raise; end if; end $$;

-- Utilisateur 1 connecté : écrit ses relevés, crée deux appareils
set role authenticated; set request.uid = '11111111-1111-1111-1111-111111111111';
insert into releves(categorie, date, valeur) values ('electricite', '2026-11-16', 467.33);
select pg_temp.doit_echouer($$insert into releves(user_id, categorie, valeur) values ('22222222-2222-2222-2222-222222222222','gaz',1)$$, 'écrire pour un autre compte');
do $$ begin
  if length(nouvelle_cle_collecteur('desktop')) <> 64 or length(nouvelle_cle_collecteur('laptop')) <> 64 then raise exception 'ÉCHEC clés'; end if;
  if (select count(*) from mes_collecteurs()) <> 2 then raise exception 'ÉCHEC : 2 appareils attendus'; end if;
  if (select count(*) from cles_collecteur) <> 0 then raise exception 'ÉCHEC : les clés sont lisibles'; end if;
end $$;
reset role;
select cle as k_desk from cles_collecteur where appareil = 'desktop' \gset
select cle as k_lap from cles_collecteur where appareil = 'laptop' \gset

-- Anonyme : lit, n'écrit pas ; collecteur avec clé, anti-doublon 10 min
set role anon; set request.uid = '';
do $$ begin if (select count(*) from releves) <> 1 then raise exception 'ÉCHEC lecture publique'; end if; end $$;
select pg_temp.doit_echouer($$insert into releves(categorie, valeur) values ('gaz',1)$$, 'écriture anonyme');
select pg_temp.doit_echouer($$select * from mes_collecteurs()$$, 'liste des appareils en anonyme');
select pg_temp.doit_echouer($$select ajouter_releve_claude('mauvaise', 1, null, 1, null)$$, 'clé inconnue');
select ajouter_releve_claude(:'k_desk', 30, null, 86, null) = 'enregistré' as ok \gset
select ajouter_releve_claude(:'k_lap', 31, null, 86, null) like 'ignoré%' as ok2 \gset
select pg_temp.verifier(:'ok' = 't', 'premier relevé enregistré');
select pg_temp.verifier(:'ok2' = 't', 'relevé à moins de 10 min ignoré');
reset role;

-- Utilisateur 2 ne peut pas retirer les appareils de l'utilisateur 1
set role authenticated; set request.uid = '22222222-2222-2222-2222-222222222222';
select supprimer_collecteur('laptop');
reset role;
do $$ begin if (select count(*) from cles_collecteur) <> 2 then raise exception 'ÉCHEC : appareil d''un autre supprimé'; end if; end $$;
