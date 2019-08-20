/* [isochrone] Conversion d'un point de coordonnées (point de départ) en géométrie. */
CREATE OR REPLACE FUNCTION coordToGeom(startingPoint double precision[]) RETURNS geometry AS $$
  DECLARE
    lon double precision;
    lat double precision;
  BEGIN
    lon := coordinatesTable[1];
    lat := coordinatesTable[2];

    RETURN st_setsrid(st_makepoint(lon, lat), 4326);
  END;
$$ LANGUAGE 'plpgsql' ;

/* [isochrone] Converstion d'un point de coordonnées vers un identifiant de vertex. */
CREATE OR REPLACE FUNCTION startingPointToVID(startingPoint double precision[]) RETURNS integer AS $$
  BEGIN
    RETURN nearest_node(startingPoint[1], startingPoint[2]);
  END ;
$$ LANGUAGE 'plpgsql' ;

/* [isochrone] Génération d'isochrone. */
CREATE OR REPLACE FUNCTION isochroneGenerator(
  startingPoint double precision [],  /* Point de départ du calcul. */
  costValue double precision,         /* Valeur du coût. */
  costName text,                      /* Nom de la colonne du coût. */
  rcostName text,                     /* Nom de la colonne de coût inverse. */
  where_clause text                   /* Clause WHERE pour la sélection d'une partie du graphe. */)
  /* TODO: Add RETURNS TABLE.. */
  DECLARE
    graph_query text;
    final_query text;
  BEGIN
    /* Requête permettant de récupèrer le graphe. */
    graph_query := concat('SELECT id, source, target, ', costName,' AS cost, ', rcostName,' AS reverse_cost FROM ways', where_clause);

    /* Création de la requête du calcul d'isochrone. */
    /* pgr_drivingDistance(edges_sql, start_vid, distance, directed)
    RETURNS SET OF (seq, node, edge, cost, agg_cost) */
    final_query := 'SELECT * FROM pgr_drivingDistance($1, startingPointToVID($2), $3)';

    /* Exécution de la requête du calcul d'isochrone. */
    RETURN QUERY EXECUTE final_query
      USING graph_query, startingPoint, costValue;
  END;
$$ LANGUAGE 'plpgsql' ;

/* [isochrone] Point d'entrée de l'API. */
CREATE OR REPLACE FUNCTION generateIsochrone(
  startingPoint double precision [],  /* Point de départ du calcul. */
  costValue double precision,         /* Valeur du coût. */
  costColumn text,                    /* Nom de la colonne du coût. */
  rcostColumn text,                   /* Nom de la colonne de coût inverse. */)
  /* TODO: Add RETURNS TABLE.. */
  DECLARE
    where_clause text;
  BEGIN
    /* P.S. Le rayon du buffer a été temporairement mis à 10. */
    where_clause = concat(' WHERE the_geom @ ( SELECT ST_Buffer( coordToGeom(''', startingPoint, ''' ), ', 10, ' ) )');

    RETURN QUERY SELECT * FROM isochroneGenerator(startingPoint, costValue, costColumn, rcostColumn, where_clause);
  END ;
$$ LANGUAGE 'plpgsql' ;
