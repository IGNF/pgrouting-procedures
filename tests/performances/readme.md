# Tests de performances sur les procédures

Le projet `pgrouting-procedures` contient plusieurs procédures pour PGRouting. Afin de mesurer les performances de ces procédures, un script R a été utilisé.

## Utilisation via Docker

### Build de l'image

Pour construire l'image, il suffit de lancer la commande suivante à la racine du projet pgrouting-procedures:
```
docker build -t pgr-perf -f tests/performances/docker/Dockerfile .
```

Les éléments suivants peuvent être spécifiés:
- DNS (host et IP)
- Proxy

```
docker build -t pgr-perf --build-arg dnsIP=$dnsIP --build-arg dnsHost=$dnsHost --build-arg proxy=$proxy -f tests/performances/docker/Dockerfile .
```

### Lancer l'application

Pour lancer l'application, il suffit d'utiliser la commande suivante:
```
docker run --name pgr-perf-test --rm -d -v $src:/home/docker/scripts pgr-perf
```

### Mode DEBUG
```
docker run --name pgr-perf-test --rm -it -v $src:/home/docker/scripts pgr-perf /bin/bash
```
