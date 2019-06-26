# Script de test des performances

# Récupération des données sur la base

dbInfo <- read.csv(file = "/run/secrets/db_config", header=TRUE, sep=",")

# Paramètres du test

## Nombre de requêtes
nbRequest <- 10
## Algo utilisé
algorithm <- "trsp"
## Colonne des coûts
costColumn <- "cost_s_car"
## Colonne des coûts inverse
reverseCostColumn <- "reverse_cost_s_car"

# Génération de coordonnées aléatoires sur l'IDF
## Nombre de coordonnées
nbCoord <- nbRequest * 2

## Génération des lat
randomLat <- runif(nbCoord, min=48.4, max=49.1)
## Génération des lon
randomLon <- runif(nbCoord, min=1.7, max=3.3)


# Mesure des requêtes SQL
mesures <- c("numeric", nbRequest)

for ( i in seq(1, nbRequest) ) {

  # Écriture de la commande
  sqlRequest <- paste("\"SELECT * FROM shortest_path_with_algorithm(ARRAY[[", randomLon[i], ",", randomLat[i], "],[", randomLon[i*2], ",", randomLat[i*2], "]],\'", costColumn, "\',\'", reverseCostColumn, "\',\'", algorithm, "\',ARRAY[\'name\'])\"", sep=" ")
  # print(sqlRequest)
  sysCmd <- paste("psql", dbInfo$database, "-U", dbInfo$user, "-h", dbInfo$host, "-c", sqlRequest, sep=" ")
  print(paste(i, sysCmd, sep=" "))

  # Mesure de la commande
  mesure <- system.time( system(sysCmd, intern=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE, timeout=60))
  mesures[i] <- mesure[3]

}

# Conversion en nombres
mesures <- as.numeric(mesures)
# print(mesures)

print(paste("Moyenne:", mean(mesures), sep=" "))
print(paste("Mediane:", median(mesures), sep=" "))
print(paste("Variance:", var(mesures), sep=" "))
print(paste("Ecart-type:", sd(mesures), sep=" "))
print(paste("Min:", min(mesures), sep=" "))
print(paste("Max:", max(mesures), sep=" "))
