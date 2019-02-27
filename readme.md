# Procédures pour PgRouting

Ce projet contient plusieurs prodécures SQL utilisables avec PgRouting.

## Installation des fonctions sur une base de données

Pour installer les fontions sql d'un fichier (ici dijstra.sql) sur une base de données à l'aide de l'utilitaire `psql` :
```sh
psql -U user -h host -d db_name -f sql/dijkstra.sql
```
