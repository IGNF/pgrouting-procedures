-- Point du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_node(lon1 double precision, lat1 double precision) RETURNS bigint AS $$
  SELECT id
  FROM ways_vertices_pgr
  ORDER BY the_geom <-> st_setsrid(st_makepoint(lon1,lat1),4326)
  LIMIT 1
$$ LANGUAGE SQL ;

-- Dijskstra entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_dijkstra(lon1 double precision,  -- longitude du 1er point
                                           lat1 double precision, -- latitude du 1er point
                                           lon2 double precision, -- longitude du 2nd point
                                           lat2 double precision, -- latitude du 2nd point
                                           costname text,         -- nom de la colonne du coût
                                           rcostname text)        -- nom de la colonne de coût inverse
  RETURNS TABLE (
    seq int,                    -- index absolu de l'étape (commence à 1)
    path_seq int,               -- index relatif entre 2 waypoints de l'étape (commence à 1)
    node bigint,                -- id du node de départ
    edge bigint,                -- id de l'edge parcouru
    cost double precision,      -- coût du tronçon
    agg_cost double precision,  -- coût aggrégé (sans le dernier coût)
    geom_json text,             -- géométrie en geojson de l'edge
    node_lon double precision,  -- longitude du node (seulement si waypoint)
    node_lat double precision   -- latitude du node (seulement si waypoint)
    ) AS $$
  SELECT path.*, ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom), ST_Y(nodes.the_geom)
  FROM pgr_dijkstra(concat('SELECT id,source,target,',
                           costname,
                           ' AS cost,',
                           rcostname,
                           ' AS reverse_cost FROM ways'
                           ),
                    nearest_node(lon1,lat1),
                    nearest_node(lon2,lat2)) AS path
  LEFT JOIN ways ON (path.edge = ways.id)
  -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
  LEFT JOIN ways_vertices_pgr AS nodes ON (path.node = nodes.id) AND (path.path_seq = 1 OR path.edge=-1)
  ORDER BY seq
$$ LANGUAGE SQL ;
