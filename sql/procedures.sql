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

-- Conversion de coordinatesTable de longeur supérieure à 2 vers un table de couple de paires de coordonnées
CREATE OR REPLACE FUNCTION coordTableToCoordCouplesTable(coordinatesTable double precision[][]) RETURNS double precision[][][] AS $$
  DECLARE
    i integer;
    result double precision[][][] DEFAULT array_fill(0, ARRAY[array_upper(coordinatesTable, 1) - 1, 2, 2]);
  BEGIN
    FOR i in 1 .. array_upper(coordinatesTable, 1) - 1
    LOOP
      result[i][1][1] := coordinatesTable[i][1] ;
      result[i][1][2] := coordinatesTable[i][2] ;
      result[i][2][1] := coordinatesTable[i+1][1] ;
      result[i][2][2] := coordinatesTable[i+1][2] ;
    END LOOP;
    RETURN result;
  END ;
$$ LANGUAGE 'plpgsql' ;


-- Conversion de coordinatesTable vers vertexIdTable
CREATE OR REPLACE FUNCTION coordTableToVIDTable(coordinatesTable double precision[][]) RETURNS integer[] AS $$
  DECLARE
    i integer;
    result integer[] DEFAULT '{}';
    nodeId integer;
  BEGIN
    FOR i in 1 .. array_upper(coordinatesTable, 1)
    LOOP
      nodeId := nearest_node(coordinatesTable[i][1], coordinatesTable[i][2]) ;
      result := array_append(result, nodeId) ;
    END LOOP;
    RETURN result;
  END ;
$$ LANGUAGE 'plpgsql' ;

-- Dijskstra entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_dijkstra(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
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
    FROM pgr_dijkstraVia(concat('SELECT id,source,target,',
                            costname,
                            ' AS cost,',
                            rcostname,
                            ' AS reverse_cost FROM ways'
                            ),
                          coordTableToVIDTable(coordinatesTable)
                          ) AS path
    LEFT JOIN ways ON (path.edge = ways.id)
    -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
    LEFT JOIN ways_vertices_pgr AS nodes ON (path.node = nodes.id) AND (path.path_seq = 1 OR path.edge=-1)
    ORDER BY seq ;
  END;
$$ LANGUAGE 'plpgsql' ;

-- A* entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_astar(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours (longueur 2)
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
  DECLARE
    vertex_ids_result integer[];
    start_vertex_id integer;
    end_vertex_id integer;
  BEGIN
    vertex_ids_result := coordTableToVIDTable(coordinatesTable);
    start_vertex_id := vertex_ids_result[1];
    end_vertex_id := vertex_ids_result[2];

    RETURN QUERY SELECT path.seq, path.path_seq, path.node::integer, path.edge::integer,
                        path.cost, path.agg_cost, ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom), ST_Y(nodes.the_geom)
    FROM pgr_aStar(concat('SELECT id::integer,source::integer,target::integer,x1,y1,x2,y2,',
                            costname,
                            ' AS cost,',
                            rcostname,
                            ' AS reverse_cost FROM ways'
                            ),
                          start_vertex_id,
                          end_vertex_id,
                          true) AS path
    LEFT JOIN ways ON (path.edge = ways.id)
    -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
    LEFT JOIN ways_vertices_pgr AS nodes ON (path.node = nodes.id) AND (path.path_seq = 1 OR path.edge=-1)
    ORDER BY seq ;
  END;
$$ LANGUAGE 'plpgsql' ;

-- trsp entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_trspVertices(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
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
    RETURN QUERY SELECT path.seq as seq,
      -- Astuce pour pouvoir détecter le passage a un nouveau waypoint car comportement très différent
      -- des autres fonctions : pas de path_seq mais un id de la route...
      -1 * path.id1 as path_seq,
      path.id1 as node, path.id2 as edge, path.cost as cost,
      SUM(cost) OVER (ORDER BY seq ASC rows between unbounded preceding and current row) as agg_cost,
      ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom), ST_Y(nodes.the_geom)
    FROM pgr_trspViaVertices(concat('SELECT id::integer,source::integer,target::integer,',
                            costname,
                            ' AS cost,',
                            rcostname,
                            ' AS reverse_cost FROM ways'
                            ),
                      coordTableToVIDTable(coordinatesTable),
                      true,
                      true) AS path
    LEFT JOIN ways ON (path.id3 = ways.id)
    -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
    LEFT JOIN ways_vertices_pgr AS nodes ON (path.id2 = nodes.id)
    ORDER BY seq ;
  END;
$$ LANGUAGE 'plpgsql' ;

-- fonction qui choisit la bonne fonction à executer
CREATE OR REPLACE FUNCTION shortest_path_with_algorithm(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                                        costname text,         -- nom de la colonne du coût
                                                        rcostname text,        -- nom de la colonne de coût inverse
                                                        algo text              -- algorithme à utiliser
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
  DECLARE
    coord_couples_table double precision[][][];
    m double precision[][];
  BEGIN
    CASE algo
      WHEN 'dijkstra' THEN
        RETURN QUERY SELECT * FROM coord_dijkstra(coordinatesTable,costname,rcostname) ;
      WHEN 'astar' THEN
        IF array_length(coordinatesTable, 1) > 2 THEN
          coord_couples_table := coordTableToCoordCouplesTable(coordinatesTable);
          FOREACH m SLICE 1 in ARRAY coord_couples_table
          LOOP
            RETURN QUERY SELECT * FROM coord_astar(m,costname,rcostname) ;
          END LOOP;
        ELSE
          RETURN QUERY SELECT * FROM coord_astar(coordinatesTable,costname,rcostname) ;
        END IF;
      WHEN 'trsp' THEN
        RETURN QUERY SELECT * FROM coord_trspVertices(coordinatesTable,costname,rcostname) ;
      ELSE
        RETURN QUERY SELECT * FROM coord_dijkstra(coordinatesTable,costname,rcostname) ;
    END CASE;
  END ;
$$ LANGUAGE 'plpgsql' ;
