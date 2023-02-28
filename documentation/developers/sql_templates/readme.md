# Utiliser les templates SQL

Pour utiliser les templates du dossier {{ '[sql_templates]({}tree/{}/sql_templates)'.format(repo_url, repo_branch) }} :
```
bash generate_all_procedures.sh <nom_du_schema>
```

Pour sauvegarder l'output dans un fichier sql :
```
bash generate_all_procedures.sh <nom_du_schema> > nom_du_fichier.sql
```

Ajouter ensuite ces fonctions à votre base de données via l'utilitaire psql par exemple : 

```
psql -h nom_hote -p num_port -U nom_utilisateur  nom_db  -f nom_du_fichier.sql
```

Le script add_procedures du dossier {{ '[scripts]({}tree/{}/scripts)'.format(repo_url, repo_branch) }} va ajouter les procédures au schéma public.

**Toujours ajouter les utilities en premier!**
