-- Conversion d'un point de coordonnées en géométrie.
CREATE OR REPLACE FUNCTION coordToGeom(location double precision[]) RETURNS geometry AS $$
  DECLARE
    lon double precision;
    lat double precision;
  BEGIN
    lon := location[1];
    lat := location[2];

    RETURN st_setsrid(st_makepoint(lon, lat), 4326);
  END;
$$ LANGUAGE 'plpgsql' ;

-- Converstion d'un point de coordonnées en un identifiant de vertex.
CREATE OR REPLACE FUNCTION locationToVID(location double precision[]) RETURNS integer AS $$
  BEGIN
    RETURN nearest_node(location[1], location[2]);
  END ;
$$ LANGUAGE 'plpgsql' ;

-- Calcul de l'isochrone et génération de la géométrie.
CREATE OR REPLACE FUNCTION isochroneGenerator(
  location double precision [],  -- Point de départ/arrivée du calcul.
  costValue double precision,    -- Valeur du coût.
  direction text,                -- Sens du parcours.
  costName text,                 -- Nom de la colonne du coût.
  rcostName text,                -- Nom de la colonne du coût inverse.
  where_clause text              -- Clause WHERE (pour ne sélectionner qu'une portion du graphe).
  )
  RETURNS TABLE (
    geometry text -- Zone de chalandise de l'isochrone (multipolygon geometry).
  ) AS $$
  DECLARE
    graph_query text;
    isochrone_query text;
    final_query text;
  BEGIN
    -- Requête permettant de récupèrer le graphe.
    IF (direction = 'arrival') THEN
      graph_query := concat('SELECT id, source, target, ', rcostName,' AS cost, ', costName,' AS reverse_cost FROM ways', where_clause);
    ELSE
      graph_query := concat('SELECT id, source, target, ', costName,' AS cost, ', rcostName,' AS reverse_cost FROM ways', where_clause);
    END IF;

    -- Requête intermédiaire, permettant de récupérer les données brutes du calcul de l'isochrone.
    isochrone_query := concat('SELECT dd.seq AS id, ST_X(v.the_geom) AS x, ST_Y(v.the_geom) AS y FROM pgr_drivingDistance($niv2$', graph_query, '$niv2$, ', locationToVID(location), ', ', costValue, ') AS dd INNER JOIN ways_vertices_pgr AS v ON dd.node = v.id');

    -- Requête permettant de générer la géométrie finale à renvoyer.
    final_query := concat('SELECT ST_AsGeoJSON(ST_SetSRID(pgr_pointsAsPolygon($1), 4326))');

    RETURN QUERY EXECUTE final_query
    USING isochrone_query;
  END;
$$ LANGUAGE 'plpgsql' ;

-- Point d'entrée de l'API.
CREATE OR REPLACE FUNCTION generateIsochrone(
    location double precision [],   -- Point de départ/arrivée du calcul.
    costValue double precision,     -- Valeur du coût.
    direction text,                 -- Sens du parcours.
    costColumn text,                -- Nom de la colonne du coût.
    rcostColumn text                -- Nom de la colonne du coût inverse.
  )
  RETURNS TABLE (
    geometry text -- Zone de chalandise de l'isochrone (multipolygon geometry).
  ) AS $$
  DECLARE
    where_clause text;
    buffer_value double precision;
  BEGIN
    -- Calcul de la valeur du 'buffer' (convertie en degrés)
    IF costColumn LIKE 'cost_m%' THEN
      buffer_value := (costValue + 10) / 112000;
    ELSIF costColumn LIKE 'cost_s%' THEN
      -- Buffer de temps * 130 km/h
      buffer_value := costValue * (130 / 3.6) / 112000;
    ELSE
      buffer_value := 1;
    END IF;
    where_clause := concat(' WHERE the_geom && (SELECT ST_Expand( ST_Extent( coordToGeom($niv3$', location, '$niv3$)),', buffer_value ,'))');

    RETURN QUERY SELECT * FROM isochroneGenerator(location, costValue, direction, costColumn, rcostColumn, where_clause);
  END;
$$ LANGUAGE 'plpgsql' ;
