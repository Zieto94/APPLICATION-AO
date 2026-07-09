-- =====================================================================
--  APPLICATION APPEL D'OFFRES — PLAN DE FORMATION 2026 (Orange CI)
--  Schéma Supabase : tables, sécurité (RLS), stockage, déclencheurs.
--  À exécuter dans : Supabase → SQL Editor → New query → Run.
--  Ré-exécutable sans risque (idempotent).
-- =====================================================================

-- ============ 1. TABLES ============

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_name text,
  role text not null default 'supplier'   -- 'supplier' ou 'admin'
);

create table if not exists public.formations (
  num       text primary key,   -- B1 .. B78
  lot       text,               -- 'LOT 1' .. 'LOT 4'
  lot_titre text,               -- 'LOT 1 – Data, Tech & Cybersécurité'
  intitule  text,
  budget    numeric,            -- budget HT de référence
  a_coter   boolean not null default true  -- false = non soumise aux fournisseurs
);

create table if not exists public.submissions (
  id            uuid primary key default gen_random_uuid(),
  formation_num text references public.formations(num) on delete cascade,
  supplier_id   uuid references auth.users(id) on delete cascade,
  company_name  text,
  montant_ht    numeric,
  tech_path text, tech_name text,
  fin_path  text, fin_name  text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (formation_num, supplier_id)
);

alter table public.profiles    enable row level security;
alter table public.formations  enable row level security;
alter table public.submissions enable row level security;

-- ============ 2. FONCTIONS UTILITAIRES ============

-- Création automatique du profil à l'inscription (nom société via metadata)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, company_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'company_name', new.email), 'supplier')
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Test « est administrateur ? »
create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- ============ 3. POLITIQUES RLS ============

-- PROFILES : chacun voit/écrit le sien ; l'admin voit tout
drop policy if exists p_prof_sel on public.profiles;
create policy p_prof_sel on public.profiles for select
  using (id = auth.uid() or public.is_admin());
drop policy if exists p_prof_ins on public.profiles;
create policy p_prof_ins on public.profiles for insert
  with check (id = auth.uid());
drop policy if exists p_prof_upd on public.profiles;
create policy p_prof_upd on public.profiles for update
  using (id = auth.uid() or public.is_admin());

-- FORMATIONS : lecture par tout utilisateur connecté ; écriture réservée admin
drop policy if exists p_form_sel on public.formations;
create policy p_form_sel on public.formations for select
  using (auth.role() = 'authenticated');
drop policy if exists p_form_all on public.formations;
create policy p_form_all on public.formations for all
  using (public.is_admin()) with check (public.is_admin());

-- SUBMISSIONS : le fournisseur ne voit/gère QUE les siennes ; l'admin voit tout
--   -> confidentialité garantie côté base : personne ne voit les offres d'autrui.
drop policy if exists p_sub_sel on public.submissions;
create policy p_sub_sel on public.submissions for select
  using (supplier_id = auth.uid() or public.is_admin());
drop policy if exists p_sub_ins on public.submissions;
create policy p_sub_ins on public.submissions for insert
  with check (supplier_id = auth.uid());
drop policy if exists p_sub_upd on public.submissions;
create policy p_sub_upd on public.submissions for update
  using (supplier_id = auth.uid());
drop policy if exists p_sub_del on public.submissions;
create policy p_sub_del on public.submissions for delete
  using (supplier_id = auth.uid() or public.is_admin());

-- ============ 4. STOCKAGE DES FICHIERS (offres tech. & fin.) ============
insert into storage.buckets (id, name, public)
values ('offres','offres', false)
on conflict (id) do nothing;

-- Chemin de fichier : <uid>/<num_formation>/... -> 1er dossier = uid du fournisseur
drop policy if exists p_obj_ins on storage.objects;
create policy p_obj_ins on storage.objects for insert to authenticated
  with check (bucket_id='offres' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists p_obj_sel on storage.objects;
create policy p_obj_sel on storage.objects for select to authenticated
  using (bucket_id='offres' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
drop policy if exists p_obj_upd on storage.objects;
create policy p_obj_upd on storage.objects for update to authenticated
  using (bucket_id='offres' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists p_obj_del on storage.objects;
create policy p_obj_del on storage.objects for delete to authenticated
  using (bucket_id='offres' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ============ 5. DONNÉES : LES 78 FORMATIONS ============
-- Seed : 78 formations (B41/B53/B55 = non cotables : a_coter=false)
insert into public.formations (num,lot,lot_titre,intitule,budget,a_coter) values
  ('B1','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Advanced Penetration Testing, Exploit Writing, and Ethical Hacking',1300000,true),
  ('B2','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Agent IA (Déploiement plateforme, architecture, configuration, utilisation)',6400000,true),
  ('B3','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Apache KAFKA Avancé',5100000,true),
  ('B4','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Apache NIFI Avancé (Déploiement plateforme, architecture, résilience , configuration, utilisation)',5100000,true),
  ('B5','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Architecture Core CS et PS',6000000,true),
  ('B6','LOT 1','LOT 1 – Data, Tech & Cybersécurité','CCZT (Certificate of Competence in Zero Trust)',13500000,true),
  ('B7','LOT 1','LOT 1 – Data, Tech & Cybersécurité','CDMP (Certificat Data management professionnel)',6000000,true),
  ('B8','LOT 1','LOT 1 – Data, Tech & Cybersécurité','CSON : Ingénierie des réseaux (intégration, optimisation, contrôle)',3600000,true),
  ('B9','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Cerfification CISM (Advanced Information Security Manager)',1250000,true),
  ('B10','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Certification CEH V13 (Certified Ethical Hacker version 13)',1000000,true),
  ('B11','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Certification CISSP (Expert Information Systems Security Professional)',1400000,true),
  ('B12','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Certification Cisco CCNP',4050000,true),
  ('B13','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Certification F5',6000000,true),
  ('B14','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Certification FOA',15000000,true),
  ('B15','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Data analyst Associate Microsoft (PL-300)',2700000,true),
  ('B16','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Développement API ET ROBOFRAMEWORK',6000000,true),
  ('B17','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Développement FULL STACK WEB APIs : AngularJs + SpringBoot',700000,true),
  ('B18','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Fondamentaux de la norme ANSI/BICSI-003',9200000,true),
  ('B19','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Fondamentaux de la norme TIA-943',9200000,true),
  ('B20','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Formation ArcGIS Entreprise',1500000,true),
  ('B21','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Formation Logiciel Tableau Software',2100000,true),
  ('B22','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Formation en Data Management et Gouvernance des données',750000,true),
  ('B23','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Formation et Certification DevSecOps Practitioner',14000000,true),
  ('B24','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Graph Mining',2400000,true),
  ('B25','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Hacking et sécurisation des APIs',5200000,true),
  ('B26','LOT 1','LOT 1 – Data, Tech & Cybersécurité','IA Générative & LLMs',3000000,true),
  ('B27','LOT 1','LOT 1 – Data, Tech & Cybersécurité','IA: Machine learning',8000000,true),
  ('B28','LOT 1','LOT 1 – Data, Tech & Cybersécurité','IP Networks QoS & Performance Management',4800000,true),
  ('B29','LOT 1','LOT 1 – Data, Tech & Cybersécurité','ISTQB Foundation',3000000,true),
  ('B30','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Marketing opérationnelle ICT',4800000,true),
  ('B31','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Microsoft Azure',2400000,true),
  ('B32','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Offre sur mesure : élaboration Offre complexe et amélioration du time to response',6600000,true),
  ('B33','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Optical Network Engineering: Quality of Service in IPoWDM/OTN Network',4500000,true),
  ('B34','LOT 1','LOT 1 – Data, Tech & Cybersécurité','POWER BI',2100000,true),
  ('B35','LOT 1','LOT 1 – Data, Tech & Cybersécurité','Power BI',2100000,true),
  ('B36','LOT 1','LOT 1 – Data, Tech & Cybersécurité','SANS FOR',26000000,true),
  ('B37','LOT 1','LOT 1 – Data, Tech & Cybersécurité','TOGAF 9.2',6000000,true),
  ('B38','LOT 2','LOT 2 – Management, RH & Gouvernance','AGILYTAE/ Construire et développer une culture d''entreprise forte',800000,true),
  ('B39','LOT 2','LOT 2 – Management, RH & Gouvernance','Certification BPM (Business Process Mapping/Management)',2000000,true),
  ('B40','LOT 2','LOT 2 – Management, RH & Gouvernance','Certification HRBP',2250000,true),
  ('B41','LOT 2','LOT 2 – Management, RH & Gouvernance','Certification Strategy@HEC Paris',2500000,false),
  ('B42','LOT 2','LOT 2 – Management, RH & Gouvernance','Diversité et inclusion : bâtir une entreprise plus forte et plus juste',1000000,true),
  ('B43','LOT 2','LOT 2 – Management, RH & Gouvernance','Droit du travail',2300000,true),
  ('B44','LOT 2','LOT 2 – Management, RH & Gouvernance','Formation Business Model & Innovation: Odyssey 3.14',3200000,true),
  ('B45','LOT 2','LOT 2 – Management, RH & Gouvernance','Formation Pilotage de portefeuilles projet',1400000,true),
  ('B46','LOT 2','LOT 2 – Management, RH & Gouvernance','Gestion prévisionelle des emplois et des compétences',1400000,true),
  ('B47','LOT 2','LOT 2 – Management, RH & Gouvernance','Marketing RH et Marque Employeur',2100000,true),
  ('B48','LOT 2','LOT 2 – Management, RH & Gouvernance','MoP® – Management of Portfolios (AXELOS)',4200000,true),
  ('B49','LOT 2','LOT 2 – Management, RH & Gouvernance','Projet - Assurance Qualité Projet',600000,true),
  ('B50','LOT 2','LOT 2 – Management, RH & Gouvernance','Rôle et posture du chargé de formation dans un cadre normé',1400000,true),
  ('B51','LOT 2','LOT 2 – Management, RH & Gouvernance','Soutien commercial des équipes',9750000,true),
  ('B52','LOT 3','LOT 3 – Business, Client & Marketing','Analytics Web and Social Media',5100000,true),
  ('B53','LOT 3','LOT 3 – Business, Client & Marketing','Certification BCEAO/HEC CEMSTRAT 1',4500000,false),
  ('B54','LOT 3','LOT 3 – Business, Client & Marketing','Certification CBM',600000,true),
  ('B55','LOT 3','LOT 3 – Business, Client & Marketing','Certification COPC',30000000,false),
  ('B56','LOT 3','LOT 3 – Business, Client & Marketing','Certification Supply Chain',5000000,true),
  ('B57','LOT 3','LOT 3 – Business, Client & Marketing','Gestion de la relation commerciale B2B',20800000,true),
  ('B58','LOT 3','LOT 3 – Business, Client & Marketing','L''expérience client & l''IA',9300000,true),
  ('B59','LOT 3','LOT 3 – Business, Client & Marketing','La gestion des clients à valeur',2250000,true),
  ('B60','LOT 3','LOT 3 – Business, Client & Marketing','Management stratégique du Route to Market',3000000,true),
  ('B61','LOT 3','LOT 3 – Business, Client & Marketing','Marketing de l''innovation',3000000,true),
  ('B62','LOT 3','LOT 3 – Business, Client & Marketing','Stratégie média',3000000,true),
  ('B63','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Certification CIA® (Certified Internal Auditor)',5200000,true),
  ('B64','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Contôle Interne - Prévention des fraudes internes',700000,true),
  ('B65','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Credit Management',2100000,true),
  ('B66','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Emprunts et investissements étrangers – Obligations réglementaires en Côte d’Ivoire',3600000,true),
  ('B67','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation - Optimiser la gestion des fournisseurs - critères Environnementaux & énergétiques de sélection et d''évaluation',2800000,true),
  ('B68','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation -Lead Auditeur CQI and IRCA ISO 14001 Environnement',700000,true),
  ('B69','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation -Lead Auditeur CQI and IRCA ISO 50001 Energie',700000,true),
  ('B70','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation Compliance et Gestion des risques',1800000,true),
  ('B71','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation sur la Conception énergétique des bâtiments & Infrastructures _ projet',2800000,true),
  ('B72','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation sur la norme ISO 50003 (Systèmes de management de l’énergie – Exigences pour les organismes procédant à l’audit et à la certification de systèmes de management de l’énergie)',3600000,true),
  ('B73','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation à la norme ISO 22301 (Management de la continuité d''activité)',700000,true),
  ('B74','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Formation à la norme ISO 27701 (Management de la protection de la vie privée)',5600000,true),
  ('B75','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Iso/ IEC 22301 Lead Implementer : continuité d''activité',3000000,true),
  ('B76','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Les achats responsables',1400000,true),
  ('B77','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Maintenance énergie dans les Data Center',3250000,true),
  ('B78','LOT 4','LOT 4 – Finance, Conformité, Audit & Normes','Traitement fiscal des immobilisations',2800000,true)
on conflict (num) do update set lot=excluded.lot, lot_titre=excluded.lot_titre, intitule=excluded.intitule, budget=excluded.budget, a_coter=excluded.a_coter;
