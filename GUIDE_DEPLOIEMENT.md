# Guide de déploiement — Application Appel d'Offres (Plan de Formation 2026)

Application web de gestion des appels d'offres : dépôt des offres par les
prestataires, rangement automatique, notation du coût et exports Excel/ZIP.

- **`index.html`** : toute l'application (un seul fichier, à ouvrir dans un navigateur).
- **`schema.sql`** : la base de données (tables, sécurité, stockage, les 78 formations).

---

## 1. Créer le projet Supabase (base de données gratuite)

1. Aller sur https://supabase.com → **Sign in** → **New project**.
2. Choisir un nom, un mot de passe de base, une région (Europe conseillé).
3. Attendre ~2 min que le projet soit prêt.

## 2. Installer la base

1. Dans le projet : menu **SQL Editor** → **New query**.
2. Copier-coller **tout** le contenu de `schema.sql` → **Run**.
   → Crée les tables, les règles de confidentialité, le stockage des fichiers,
   et charge les **78 formations avec leurs budgets**.
   (Le script est ré-exécutable sans risque.)

## 3. Désactiver la confirmation par e-mail

La connexion se fait par **nom d'entreprise** (converti en e-mail technique
interne), il ne faut donc pas de validation d'e-mail :

- Menu **Authentication → Providers → Email** → décocher **Confirm email** → **Save**.

## 4. Brancher l'application sur la base

1. Dans Supabase : **Project Settings → API**.
2. Copier **Project URL** et la clé **anon public**.
3. Ouvrir `index.html`, en haut du script remplir :
   ```js
   const SUPABASE_URL      = "https://xxxx.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...";
   ```
   *(Les valeurs actuelles pointent déjà vers un projet ; remplacez-les par les vôtres.)*

## 5. Créer le compte administrateur (OCI)

1. Ouvrir `index.html`, cliquer **S'inscrire**, saisir un nom (ex. `ADMINISTRATEUR OCI`)
   + un mot de passe → **Créer mon compte**.
2. Dans Supabase → **SQL Editor**, exécuter :
   ```sql
   update public.profiles set role = 'admin'
   where company_name = 'ADMINISTRATEUR OCI';
   ```
3. Se reconnecter : l'espace **Administration** apparaît.

## 6. Mettre l'application en ligne (pour les prestataires)

`index.html` est autonome. Hébergement gratuit le plus simple :

- **Netlify Drop** : https://app.netlify.com/drop → glisser `index.html` → lien public.
- ou **GitHub Pages**, **Vercel**, ou tout hébergeur de fichiers statiques.

Communiquer le lien aux ~15 prestataires.

---

## Utilisation

### Prestataire
1. **S'inscrire** avec le nom exact de sa société + un mot de passe (aucun e-mail).
2. Choisir une formation → saisir le **montant HT** → joindre **offre technique**
   + **offre financière** → **Déposer**.
3. Il ne voit **que ses propres** soumissions (confidentialité garantie côté base).

### Administrateur
- **Arborescence** : LOT → formation → prestataire ; télécharger chaque offre,
  voir la **note coût /10**, exporter la fiche d'évaluation d'une formation.
- **Budgets** : ajuster le budget de référence (base de la notation du coût).
- **Récap & Export** :
  - **Récap Excel** : 78 formations × budget × montant HT par prestataire.
  - **Archive ZIP** : `LOT / Bx_Intitulé / Prestataire / (offres)` +
    fiche d'évaluation par formation + récap global.

---

## Règles métier

- **Note « Coût de la prestation » /10** : le budget vaut **6**.
  Moins cher → la note monte vers **10** ; plus cher → elle descend vers **1**
  (bornée entre 1 et 10). *Note pondérée = pondération (0,5) × Note/10.*
  Les critères techniques (Habilitation FDFP, Expertise, Proposition technique)
  restent **vides** : notation manuelle.
- **B41, B53, B55** sont marquées **non cotables** (`a_coter = false`) : invisibles
  pour les prestataires, laissées vides dans le récap. Pour les réactiver :
  `update public.formations set a_coter = true where num in ('B41','B53','B55');`
