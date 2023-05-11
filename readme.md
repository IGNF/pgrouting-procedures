# Procédures pour PgRouting

## Présentation

Ce projet contient plusieurs procédures SQL utilisables avec PgRouting afin de calculer des itinéraires et des isochrones plus facilement.

Ces procèdures sont utilisées par le projet [Road2](https://github.com/IGNF/road2).

## Installation des fonctions sur une base de données

### Prérequis

Afin d'utiliser ces procèdures, il est nécessaire d'avoir une base de données sur laquelle PGRouting est déjà installé.

### Installation

Il y a plusieurs fichiers SQL qui se répartissent l'ensemble des procèdures disponibles. Ces fichiers sont des templates, auxquels il faut fournir le nom de schéma. Ces fichiers sont dans le dossier [sql_templates](./sql_templates).

Pour installer toutes les fonctions ou une partie, il faudra suivre la procédure décrite dans la page dédiée de la documentation.

### Docker

Une image docker est disponible dans le dossier [docker](./docker). Cette image propose une base de donnée avec PGRouting et les procèdures.

## Version

Version des procèdures: 2.2.0-DEVELOP

## Licence

PgRouting est diffusé sous la licence GPL v3.
