# Installation des fonctions sur une base de données

## Prérequis

Afin d'utiliser ces procèdures, il est nécessaire d'avoir une base de données sur laquelle PGRouting est déjà installé.

## Installation

Il y a plusieurs fichiers SQL qui se répartissent l'ensemble des procèdures disponibles. Ces fichiers sont tous dans le dossier {{ '[sql]({}tree/{}/sql)'.format(repo_url, repo_branch) }}.

Pour installer toutes les fonctions ou une partie, il suffira de se servir de l'utilitaire `psql`:
```sh
psql -U user -h host -d db_name -f sql/routeProcedures.sql
```

Il est également possible d'utiliser un script bash pour intégrer ces procèdures en utilisant un nom de schéma particulier. On se reportera au dossier {{ '[sql_templates]({}tree/{}/sql_templates)'.format(repo_url, repo_branch) }}.