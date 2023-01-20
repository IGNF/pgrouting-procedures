# PGRouting-procedures sur Debian

Cette image permet d'avoir PGRouting-procedures et donc une base de données et des procédures pour calculer des itinéraires. 

## Construction de l'image 

Build de l'image 
```
docker build -t pgr-debian -f docker/debian/Dockerfile .
```

## Utilation de l'image 

Des éléments sont données sur les pages suivantes : 
- https://hub.docker.com/_/postgres
- https://github.com/pgRouting/docker-pgrouting 

```
docker run --rm -e POSTGRES_PASSWORD=password pgr-debian
```
