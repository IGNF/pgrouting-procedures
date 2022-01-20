# Procédures pour PgRouting

## Présentation 

Ce projet contient plusieurs procédures SQL utilisables avec PgRouting afin de calculer des itinéraires et des isochrones plus facilement.

Ces procèdures sont utilisées par le projet [Road2](https://github.com/IGNF/road2). 

## Installation des fonctions sur une base de données

### Prérequis 

Afin d'utiliser ces procèdures, il est nécessaire d'avoir une base de données sur laquelle PGRouting est déjà installé. 

### Installation 

Il y a plusieurs fichiers SQL qui se répartissent l'ensemble des procèdures disponibles. Ces fichiers sont tous dans le dossier [sql](./sql). 

Pour installer toutes les fonctions ou une partie, il suffira de se servir de l'utilitaire `psql`:
```sh
psql -U user -h host -d db_name -f sql/routeProcedures.sql
```

Il est également possible d'utiliser un script bash pour intégrer ces procèdures en utilisant un nom de schéma particulier. On se reportera au dossier [sql_template](./sql_template). 

### Docker 

Une image docker est disponible dans le dossier [docker](./docker). Cette image propose une base de donnée avec PGRouting et les procèdures. 

## Version

Version des procèdures: 1.0.5

## Licence 

PgRouting est diffusé sous la licence GPL v3. 