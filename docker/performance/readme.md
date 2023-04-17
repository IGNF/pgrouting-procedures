# Tests de performances sur les procédures

Le projet `pgrouting-procedures` contient plusieurs procédures pour PGRouting. Afin de mesurer les performances de ces procédures, un script R a été utilisé. *Cette image n'est fonctionnelle qu'avec Docker-compose.*

## Utilisation

### Build de l'image

#### Pré-requis

Pour utiliser ce `docker-compose.yml`, il suffit de :
- installer `docker`.
- se placer dans le dossier `/docker/performance` du projet pgrouting-procedures.
- créer un fichier `.env` à côté du `docker-compose.yml` qui sera une copie adaptée du `compose.env.example`

#### Gestion des variables

Lors du build des images puis lors de l'utilisation des services, il y a plusieurs paramètres qui peuvent varier. Ces paramètres sont indiqués dans le fichier `docker-compose.yml` par la syntaxe `${var}` ou par des secrets docker.

#### Le fichier .env

Les paramètres du type `${var}` sont initialisés dans le fichier `.env` qui se trouve à côté du `docker-compose.yml`. Ce fichier n'existe pas. Il faut le créer en copiant et en adaptant le fichier `compose.env.example`. le `.env` est ignoré par git.

#### Les secrets

Les secrets permettent de transférer des données sensibles. Dans notre cas, ils sont utile pour se connecter à la base de données qui est testée.

#### Build

Pour construire l'image, il suffit de lancer la commande suivante dans `/docker/performance/`:
```
docker-compose build
```

Les éléments suivants peuvent être spécifiés:
- DNS (host et IP)
- Proxy

### Lancer l'application

#### Pré-requis

Il faut avoir lancé la base de données que l'on veut tester. On pourra utiliser le docker-compose du projet `Road2` pour lancer uniquement une base.

Le fichier `pgr_config.csv` doit être indiqué dans `.env` et il doit être rempli de la manière suivante:
```
host, database, user, password, port
"x.x.x.x", "pgrouting", "postgres", "postgres", "5432"
```



#### Lancement

Pour lancer l'application, il suffit d'utiliser la commande suivante:
```
docker-compose up
```
