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
    temp_fraction float;
    nedge_id int;
  BEGIN

    -- Point temporaire
    nedge_id := nearest_edge(location[1], location[2], costname, rcostname, where_clause);

    -- Si ce point nedge_id n'exite pas, on s'arrete et on renvoit un tableau vide
    IF nedge_id IS NULL THEN
      RETURN;
    END IF;

    temp_fraction := ST_LineLocatePoint(
      (SELECT the_geom FROM ways
        WHERE id = nedge_id
      ),
      st_setsrid(st_makepoint(location[1], location[2]),4326)
    );

    -- Si ce point temp_fraction n'exite pas, on s'arrete et on renvoit un tableau vide
    IF temp_fraction IS NULL THEN
      RETURN;
    END IF;

    CREATE TEMP TABLE temp_point ON COMMIT DROP AS
      SELECT
        -1 as id,
        ST_LineInterpolatePoint(
          (SELECT the_geom FROM ways WHERE id = nedge_id),
          temp_fraction
        ) as the_geom
    ;

    -- Arcs temporaires
    EXECUTE concat('CREATE TEMP TABLE temp_edges ON COMMIT DROP AS
      -- arc de source vers -1
      (SELECT
        -1 as id,
        source as source,
        -1 as target,
        ', temp_fraction, ' * ', costName, ' as ', costName, ',
        ', temp_fraction, ' * ', rcostName, ' as ', rcostName, '
      FROM ways
      WHERE id = ', nedge_id, ')
      UNION
      -- arc de -1 vers target
      (SELECT
        -2 as id,
        -1 as source,
        target as target,
        (1 - ', temp_fraction, ') * ', costName, ' as ', costName, ',
        (1 - ', temp_fraction, ') * ', rcostName, ' as ', rcostName, '
      FROM ways
      WHERE id = ', nedge_id, ')')
    ;

    -- Requête permettant de récupèrer le graphe.
    IF (direction = 'arrival') THEN
      graph_query := concat('SELECT id, source, target, ', rcostName,' AS cost, ', costName,' AS reverse_cost FROM ways', where_clause, ' UNION SELECT * from temp_edges');
    ELSE
      graph_query := concat('SELECT id, source, target, ', costName,' AS cost, ', rcostName,' AS reverse_cost FROM ways', where_clause, ' UNION SELECT * from temp_edges');
    END IF;

    -- Requête intermédiaire, permettant de récupérer les données brutes du calcul de l'isochrone.
    isochrone_query := concat('SELECT ST_Union(geoms.the_geom) AS union FROM (SELECT v.the_geom AS the_geom FROM pgr_drivingDistance($niv2$', graph_query, '$niv2$, -1, ', costValue, ', true) AS dd INNER JOIN ways_vertices_pgr AS v ON dd.node = v.id) AS geoms');
    -- Requête permettant de générer la géométrie finale à renvoyer.
    final_query := concat('SELECT ST_AsGeoJSON(ST_SetSRID(ST_ForceRHR(ST_ConcaveHull(u.union, 0.7)), 4326)) FROM (', isochrone_query, ') AS u');

    RETURN QUERY EXECUTE final_query;
  END;
$$ LANGUAGE 'plpgsql' ;

-- Point d'entrée de l'API.
CREATE OR REPLACE FUNCTION generateIsochrone(
    location double precision [],   -- Point de départ/arrivée du calcul.
    costValue double precision,     -- Valeur du coût.
    direction text,                 -- Sens du parcours.
    costColumn text,                -- Nom de la colonne du coût.
    rcostColumn text,               -- Nom de la colonne du coût inverse.
    constraints text                -- Contraintes d'inclusion/exclusion.
  )
  RETURNS TABLE (
    geometry text -- Zone de chalandise de l'isochrone (multipolygon geometry).
  ) AS $$
  DECLARE
    where_clause text;
    buffer_value double precision;
  BEGIN
    -- Calcul de la valeur du 'buffer' (convertie en degrés)
    IF costColumn LIKE '%cost_m%' THEN
      buffer_value := (costValue + 50) / 100000::float;
    ELSIF costColumn LIKE '%cost_s_car%' THEN
      -- Buffer de temps * 130 km/h
      buffer_value := costValue * (130 / 3.6) / 100000::float;
    ELSIF costColumn LIKE '%cost_s_pedestrian%' THEN
      -- Buffer de temps * 4.2 km/h
      buffer_value := costValue * (4.2 / 3.6) / 100000::float;
    ELSE
      buffer_value := 1;
    END IF;
    where_clause := concat(' WHERE ways.the_geom && (SELECT ST_Expand( ST_Extent( coordToGeom($niv3$', location, '$niv3$)),', buffer_value ,'))');
    IF constraints != ''
    THEN
      where_clause := concat(where_clause, ' AND ', constraints);
    END IF;
    RETURN QUERY SELECT * FROM isochroneGenerator(location, costValue, direction, costColumn, rcostColumn, where_clause);
  END;
$$ LANGUAGE 'plpgsql' ;
