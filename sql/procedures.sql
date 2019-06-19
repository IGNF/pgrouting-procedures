-- Point du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_node(lon1 double precision, lat1 double precision) RETURNS integer AS $$
  DECLARE
    result integer;
  BEGIN
    SELECT INTO result id::integer
    FROM ways_vertices_pgr
    ORDER BY the_geom <-> st_setsrid(st_makepoint(lon1,lat1),4326)
    LIMIT 1 ;
    RETURN result ;
  END ;
$$ LANGUAGE 'plpgsql' ;

-- Dijskstra entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_dijkstra(lon1 double precision, -- longitude du 1er point
                                          lat1 double precision, -- latitude du 1er point
                                          lon2 double precision, -- longitude du 2nd point
                                          lat2 double precision, -- latitude du 2nd point
                                          costname text,         -- nom de la colonne du coût
                                          rcostname text)        -- nom de la colonne de coût inverse
  RETURNS TABLE (
    seq int,                    -- index absolu de l'étape (commence à 1)
    path_seq int,               -- index relatif entre 2 waypoints de l'étape (commence à 1)
    node int,                -- id du node de départ
    edge int,                -- id de l'edge parcouru
    cost double precision,      -- coût du tronçon
    agg_cost double precision,  -- coût aggrégé (sans le dernier coût)
    geom_json text,             -- géométrie en geojson de l'edge
    node_lon double precision,  -- longitude du node (seulement si waypoint)
    node_lat double precision   -- latitude du node (seulement si waypoint)
    ) AS $$
  BEGIN
    RETURN QUERY SELECT path.seq, path.path_seq, path.node::integer, path.edge::integer,
                        path.cost, path.agg_cost, ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom), ST_Y(nodes.the_geom)
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
    ORDER BY seq ;
  END;
$$ LANGUAGE 'plpgsql' ;

-- A* entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_astar(lon1 double precision, -- longitude du 1er point
                                       lat1 double precision, -- latitude du 1er point
                                       lon2 double precision, -- longitude du 2nd point
                                       lat2 double precision, -- latitude du 2nd point
                                       costname text,         -- nom de la colonne du coût
                                       rcostname text)        -- nom de la colonne de coût inverse
  RETURNS TABLE (
    seq int,                    -- index absolu de l'étape (commence à 1)
    path_seq int,               -- index relatif entre 2 waypoints de l'étape (commence à 1)
    node int,                -- id du node de départ
    edge int,                -- id de l'edge parcouru
    cost double precision,      -- coût du tronçon
    agg_cost double precision,  -- coût aggrégé (sans le dernier coût)
    geom_json text,             -- géométrie en geojson de l'edge
    node_lon double precision,  -- longitude du node (seulement si waypoint)
    node_lat double precision   -- latitude du node (seulement si waypoint)
    ) AS $$
  BEGIN
    RETURN QUERY SELECT path.seq, path.path_seq, path.node::integer, path.edge::integer,
                        path.cost, path.agg_cost, ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom), ST_Y(nodes.the_geom)
    FROM pgr_aStar(concat('SELECT id::integer,source::integer,target::integer,x1,y1,x2,y2,',
                            costname,
                            ' AS cost,',
                            rcostname,
                            ' AS reverse_cost FROM ways'
                            ),
                      nearest_node(lon1,lat1),
                      nearest_node(lon2,lat2),
                      true) AS path
    LEFT JOIN ways ON (path.edge = ways.id)
    -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
    LEFT JOIN ways_vertices_pgr AS nodes ON (path.node = nodes.id) AND (path.path_seq = 1 OR path.edge=-1)
    ORDER BY seq ;
  END;
$$ LANGUAGE 'plpgsql' ;

-- trsp entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_trsp(lon1 double precision, -- longitude du 1er point
                                      lat1 double precision, -- latitude du 1er point
                                      lon2 double precision, -- longitude du 2nd point
                                      lat2 double precision, -- latitude du 2nd point
                                      costname text,         -- nom de la colonne du coût
                                      rcostname text)        -- nom de la colonne de coût inverse
  RETURNS TABLE (
    seq int,                    -- index absolu de l'étape (commence à 1)
    path_seq int,               -- index relatif entre 2 waypoints de l'étape (commence à 1)
    node int,                -- id du node de départ
    edge int,                -- id de l'edge parcouru
    cost double precision,      -- coût du tronçon
    agg_cost double precision,  -- coût aggrégé (sans le dernier coût)
    geom_json text,             -- géométrie en geojson de l'edge
    node_lon double precision,  -- longitude du node (seulement si waypoint)
    node_lat double precision   -- latitude du node (seulement si waypoint)
    ) AS $$
  BEGIN
    RETURN QUERY SELECT path.seq + 1 as seq, path.seq + 1 as path_seq, path.id1 as node,
      path.id2 as edge, path.cost as cost,
      SUM(cost) OVER (ORDER BY seq ASC rows between unbounded preceding and current row) as agg_cost,
      ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom), ST_Y(nodes.the_geom)
    FROM pgr_trsp(concat('SELECT id::integer,source::integer,target::integer,',
                            costname,
                            ' AS cost,',
                            rcostname,
                            ' AS reverse_cost FROM ways'
                            ),
                      nearest_node(lon1,lat1),
                      nearest_node(lon2,lat2),
                      true,
                      true) AS path
    LEFT JOIN ways ON (path.id2 = ways.id)
    -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
    LEFT JOIN ways_vertices_pgr AS nodes ON (path.id1 = nodes.id) AND (path.seq=0 OR path.id2=-1)

    -- Si on fait les VIAS, route_id est l'id1, node est l'id2 et edge est l'id3 ---> nécessité de faire une autre fonction
    ORDER BY seq ;
  END;
$$ LANGUAGE 'plpgsql' ;

-- fonction qui choisit la bonne fonction à executer
CREATE OR REPLACE FUNCTION shortest_path_with_algorithm(lon1 double precision, -- longitude du 1er point
                                      lat1 double precision, -- latitude du 1er point
                                      lon2 double precision, -- longitude du 2nd point
                                      lat2 double precision, -- latitude du 2nd point
                                      costname text,         -- nom de la colonne du coût
                                      rcostname text,        -- nom de la colonne de coût inverse
                                      algo text,             -- algorithme à utiliser
                                      intermediates double precision[][] -- points intermediaires
                                      )
  RETURNS TABLE (
      seq int,                    -- index absolu de l'étape (commence à 1)
      path_seq int,               -- index relatif entre 2 waypoints de l'étape (commence à 1)
      node int,                -- id du node de départ
      edge int,                -- id de l'edge parcouru
      cost double precision,      -- coût du tronçon
      agg_cost double precision,  -- coût aggrégé (sans le dernier coût)
      geom_json text,             -- géométrie en geojson de l'edge
      node_lon double precision,  -- longitude du node (seulement si waypoint)
      node_lat double precision   -- latitude du node (seulement si waypoint)
      ) AS $$
  BEGIN
    IF array_length(intermediates, 1) > 0 THEN
      CASE algo
        WHEN 'dijkstra' THEN
          RETURN QUERY SELECT * FROM coord_dijkstra(lon1,lat1,lon2,lat2,costname,rcostname) ;
        WHEN 'astar' THEN
          RETURN QUERY SELECT * FROM coord_astar(lon1,lat1,lon2,lat2,costname,rcostname) ;
        WHEN 'trsp' THEN
          RETURN QUERY SELECT * FROM coord_trsp(lon1,lat1,lon2,lat2,costname,rcostname) ;
        ELSE
          RETURN QUERY SELECT * FROM coord_dijkstra(lon1,lat1,lon2,lat2,costname,rcostname) ;
      END CASE;
    ELSE
      CASE algo
        WHEN 'dijkstra' THEN
          RETURN QUERY SELECT * FROM coord_dijkstra(lon1,lat1,lon2,lat2,costname,rcostname) ;
        WHEN 'astar' THEN
          RETURN QUERY SELECT * FROM coord_astar(lon1,lat1,lon2,lat2,costname,rcostname) ;
        WHEN 'trsp' THEN
          RETURN QUERY SELECT * FROM coord_trsp(lon1,lat1,lon2,lat2,costname,rcostname) ;
        ELSE
          RETURN QUERY SELECT * FROM coord_dijkstra(lon1,lat1,lon2,lat2,costname,rcostname) ;
      END CASE;
    END IF;
  END ;
$$ LANGUAGE 'plpgsql' ;
