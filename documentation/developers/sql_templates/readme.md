# Utiliser les templates SQL

Pour utiliser les templates du dossier `sql_templates` :
```
bash generate_all_procedures.sh <nom_du_schema>
```

Pour sauvegarder l'output dans un fichier sql :
```
bash generate_all_procedures.sh <nom_du_schema> > nom_du_fichier.sql
```


Le script add_procedures du dossier `scripts` va ajouter les procédures au schéma public.

**Toujours ajouter les utilities en premier!**
