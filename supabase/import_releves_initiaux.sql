-- Reprend les relevés saisis avant Supabase (anciens fichiers data/*.csv).
-- À lancer UNE fois, après avoir créé ton compte (Authentication → Users).
-- Les lignes sont attribuées au premier compte créé.
insert into public.releves (user_id, categorie, date, valeur, plein_complet, note)
select id, 'electricite', '2026-11-16', 467.33, null, null from auth.users order by created_at limit 1;
insert into public.releves (user_id, categorie, date, valeur, plein_complet, note)
select id, 'carburant', '2026-11-16', 213217, false, 'relevé compteur (sans plein)' from auth.users order by created_at limit 1;
