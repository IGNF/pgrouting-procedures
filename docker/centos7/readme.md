# Dockerfile pour utiliser PGRouting-procedures sous CentOS

# Configuration de l'image (connection à pgsql)

Pour configurer le mode d'accès à la base pgsql du container, modifier la fin du fichier data/pg_hba.conf pour pouvoir se connecter au serveur de base de données depuis l'extérieur (se référer à la documentation de postgresql pour plus de détails).
Lors de la construction de l'image, il est possible de spécifier l'ensemble des ip qui auront accès à la base.

# Construction de l'image

Pour construire l'image, il suffit de lancer la commande suivante à la racine du projet :
```
docker build -t centos-pgrouting -f docker/centos/Dockerfile .
```

Les éléments suivants peuvent être spécifiés:
- Proxy (ex. "http://proxy:3128")
- ipRange (ex. "10.10.0.0/24")

```
docker build -t centos-pgrouting --build-arg proxy=$proxy --build-arg ipRange=$iprange -f docker/centos/Dockerfile .
```

# Lancer le serveur de base de données :

Pour lancer le serveur une première fois (et ainsi créer une base de données avec les extensions postgis et pgrouting), il faut spécifier un utilisateur, un mot de passe et un nom de base de données :
```
docker run -d -p 5432:5432 -v /home/amaury/pgrouting-procedures/data:/var/lib/pgsql/data --name pgrouting --env 'DB_USER=amaury' --env 'DB_PASS=test' --env 'DB_NAME=routing' centos-pgrouting
```

S'il ne faut pas créer de base de données, la commande suivante suffira :
```
docker run -d -p 5432:5432 -v /home/amaury/pgrouting-procedures/data:/var/lib/pgsql/data --name pgrouting centos-pgrouting
```

# Se connecter au serveur de base de données via psql

On pourra se connecter à la base de données créée plus haut via cette commande (lancée depuis la machine hôte) :
```
psql routing -U amaury -h $(docker inspect --format {{.NetworkSettings.IPAddress}} pgrouting)
```

Si aucune base de données n'a été créée, lancer alors cette commande :
```
psql -U postgres -h $(docker inspect --format {{.NetworkSettings.IPAddress}} pgrouting)
```

Dans les 2 cas, le client en ligne de commandes sera lancé localement sur le serveur de base de données.

## Connexion au serveur

Tant que le conteneur est en état de marche, on pourra se connecter à la base de données. Exemple d'utilisation en utilisant osm2pgrouting :
```
osm2pgrouting -f corse-latest.osm -d routing -U amaury -h $(docker inspect --format {{.NetworkSettings.IPAddress}} pgrouting)
```

## Arrêter et relancer le serveur

Pour arrêter le serveur, entrer la commande :
```
docker stop pgrouting
```
Pour le relancer, entrer la commande :
```
docker start pgrouting
```
