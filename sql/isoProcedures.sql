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
$$ LANGUAGE PLPGSQL;

-- Converstion d'un point de coordonnées en un identifiant de vertex.
CREATE OR REPLACE FUNCTION locationToVID(location double precision[]) RETURNS integer AS $$
  BEGIN
    RETURN nearest_node(location[1], location[2]);
  END ;
$$ LANGUAGE PLPGSQL;

-- Calcul de l'iso et génération de la géométrie.
CREATE OR REPLACE FUNCTION isoGenerator(
  location double precision [],  -- Point de départ/arrivée du calcul.
  costValue double precision,    -- Valeur du coût.
  direction text,                -- Sens du parcours.
  costName text,                 -- Nom de la colonne du coût.
  rcostName text,                -- Nom de la colonne du coût inverse.
  where_clause text              -- Clause WHERE (pour ne sélectionner qu'une portion du graphe).
  )
  RETURNS TABLE (
    geojson text -- Zone de chalandise de l'iso.
  ) AS $$
  DECLARE
    graph_query text;
    iso_query text;
    final_query text;
  BEGIN
    -- Requête permettant de récupèrer le graphe.
    IF (direction = 'arrival') THEN
      graph_query = concat('SELECT id, source, target, ', rcostName,' AS cost, ', costName,' AS reverse_cost FROM ways');
    ELSE
      graph_query = concat('SELECT id, source, target, ', costName,' AS cost, ', rcostName,' AS reverse_cost FROM ways');
    END IF;

    -- Requête intermédiaire, permettant de récupérer les données brutes du calcul de l'iso.
    iso_query = concat('SELECT dd.seq AS id, ST_X(v.the_geom) AS x, ST_Y(v.the_geom) AS y FROM pgr_drivingDistance(''''', graph_query, ''''', ', locationToVID(location), ', ', costValue, ') AS dd INNER JOIN ways_vertices_pgr AS v ON dd.node = v.id');

    -- Requête permettant de générer la géométrie finale à renvoyer.
    final_query = concat('SELECT ST_AsGeoJSON (ST_SetSRID(pgr_pointsAsPolygon($1), 4326)) AS geojson');

    RETURN QUERY EXECUTE final_query
    USING iso_query;
  END;
$$ LANGUAGE PLPGSQL;

-- Point d'entrée de l'API.
CREATE OR REPLACE FUNCTION generateIso(
    location double precision [],   -- Point de départ/arrivée du calcul.
    costValue double precision,     -- Valeur du coût.
    direction text,                 -- Sens du parcours.
    costColumn text,                -- Nom de la colonne du coût.
    rcostColumn text                -- Nom de la colonne du coût inverse.
  )
  RETURNS TABLE (
    geojson text -- Zone de chalandise de l'iso.
  ) AS $$
  DECLARE
    where_clause text;
  BEGIN
    where_clause = concat(' WHERE the_geom && (SELECT ST_Buffer(''''', coordToGeom(location), ''''', ', costValue, '))');

    RETURN QUERY SELECT * FROM isoGenerator(location, costValue, direction, costColumn, rcostColumn, where_clause);
  END;
$$ LANGUAGE PLPGSQL;
