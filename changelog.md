# CHANGELOG

## 2.1.2

FIXED:
- correction pour éviter de publier github pages sur un tag

## 2.1.1

CHANGED:
- reference de la doc à la branche master
- modification de la ci github pour prendre en compte la branche master

## 2.1.0

FEAT:
- genération de l'image docker sur GitHub Container registry
- suppression de code dupliqué pour la génération des procédures et des tables
- gestion de l'hôte et du mot de passe pour la génération des procédures
- ajout d'une option pour la création des bases lors de la génération des procédures

DOC:
- Ajout de la documentation sur GitHub pages

## 2.0.0

BREAKING CHANGE:
- Les procèdures d'isochrones ne prennent plus en compte le paramètre projection (il ne fonctionnait pas en l'état)

DOC:
- Maj du readme

## 1.0.6

FEAT:
- Utilisation de ST_ForceRHR pour les isochrones

## 1.0.5

DOC:
- Maj du readme

## 1.0.4

CHANGE : 
- modification de la partie docker 
- gestion du schéma dans les scripts SQL
