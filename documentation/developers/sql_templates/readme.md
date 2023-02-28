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

Le script add_procedures du dossier {{ '[scripts]({}tree/{}/scripts)'.format(repo_url, repo_branch) }} va ajouter les procédures au schéma public s'il est lancé sans options.

Il est possible d'ajouter des options à ce script pour personnaliser l'emplacement d'execution et de connexion base de données : 

- `--schema` ou `-s` suivi du nom de schema à créer et ou utiliser
- `--hote` ou `-h` suivi du nom de l'hôte pour la connexion base de données  
- `--port` ou `-p` suivi du numéro de port pour la connexion base de données
- `--user` ou `-u` suivi du nom d'utilisateur pour la connexion base de données (attention connexion sans mot de passe)
- `--dbname` ou `-d` suivi du nom de la base de données
- `--templates-dir` ou `-td` suivi de l'emplacement du dossier contenant les templates sql (sql_templates)
- `--work-dir` ou `-wd` suivi de l'emplacement du dossier d'écriture des scripts SQL modifiés
- `--no-create-dbs` ou `ndbs` pour sauter l'étape de création de la base, de la base pivot et du schéma. 

**Toujours ajouter les utilities en premier!**
