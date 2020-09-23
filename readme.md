# Procédures pour PgRouting

Ce projet contient plusieurs procédures SQL utilisables avec PgRouting.

## Installation des fonctions sur une base de données

Pour installer les fontions sql d'un fichier (e.g. routeProcedures.sql) sur une base de données à l'aide de l'utilitaire `psql` :
```sh
psql -U user -h host -d db_name -f sql/routeProcedures.sql
```
## Version 

Version des procèdures: 1.0.02-DEVELOP
