Pour utiliser les templates :
```
bash generate_utilities.sh <nom_du_schema>
```

Pour sauvegarder l'output dans un fichier sql :
```
bash generate_utilities.sh <nom_du_schema> > nom_du_fichier.sql
```


Le script add_procedures du dossier docker/centos7/data peut prendre en paramètre un nom de schema.
Il va alors ajouter les procédures au schéma spécifé. (sans schéma scpécifié, elles seront ajoutées à public)

!!! Toujours ajouter les utilities en premier
