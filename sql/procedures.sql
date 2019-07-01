-- Fonctions utilitaires
----------------------------------------------------------------------------------------------------

-- Noeud du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_node(lon1 double precision, lat1 double precision) RETURNS integer AS $$
  DECLARE
    result integer;
  BEGIN
    SELECT INTO result id::integer
    FROM ways_vertices_pgr
    WHERE ST_DWithin(Geography(st_setsrid(st_makepoint(lon1,lat1),4326)),Geography(the_geom),1000)
    ORDER BY the_geom <-> st_setsrid(st_makepoint(lon1,lat1),4326)
    LIMIT 1 ;
    RETURN result ;
  END ;
$$ LANGUAGE 'plpgsql' ;


-- Arc du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_edge(lon1 double precision, lat1 double precision) RETURNS integer AS $$
  DECLARE
    result integer;
  BEGIN
    SELECT INTO result id::integerq
    FROM ways
    -- WHERE ST_DWithin(Geography(st_setsrid(st_makepoint(lon1,lat1),4326)),Geography(the_geom),1000)
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


-- Conversion de coordinatesTable vers centroid
CREATE OR REPLACE FUNCTION coordTableCentroid(coordinatesTable double precision[][]) RETURNS geography AS $$
  DECLARE
    i integer;
    multigeom geometry;
    result geography;
    lon double precision;
    lat double precision;
  BEGIN
    lon := coordinatesTable[1][1] ;
    lat := coordinatesTable[1][2] ;
    multigeom := st_setsrid(st_makepoint(lon,lat),4326);
    FOR i in 2 .. array_upper(coordinatesTable, 1)
    LOOP
      lon := coordinatesTable[i][1] ;
      lat := coordinatesTable[i][2] ;
      multigeom := ST_Union(multigeom, st_setsrid(st_makepoint(lon,lat),4326)) ;
    END LOOP ;
    result := ST_Centroid(Geography(multigeom)) ;
    RETURN result;
  END;
$$ LANGUAGE 'plpgsql' ;


-- Plus grande distance d'un point de coord table à son centroid
CREATE OR REPLACE FUNCTION farthestDistanceFromCentroid(coordinatesTable double precision[][], centroid geography) RETURNS double precision AS $$
  DECLARE
    i integer;
    dist double precision;
    result double precision;
    lon double precision;
    lat double precision;
  BEGIN
    lon := coordinatesTable[1][1] ;
    lat := coordinatesTable[1][2] ;
    result := ST_Distance(st_setsrid(st_makepoint(lon,lat),4326), centroid::geometry) ;
    FOR i in 2 .. array_upper(coordinatesTable, 1)
    LOOP
      lon := coordinatesTable[i][1] ;
      lat := coordinatesTable[i][2] ;
      dist := ST_Distance(st_setsrid(st_makepoint(lon,lat),4326), centroid::geometry) ;
      IF dist > result THEN
        result := dist;
      END IF;
    END LOOP;
    RETURN result;
  END;
$$ LANGUAGE 'plpgsql' ;


-- Fonctions de routing
----------------------------------------------------------------------------------------------------

-- Dijskstra entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_dijkstra(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                          costname text,         -- nom de la colonne du coût
                                          rcostname text,        -- nom de la colonne de coût inverse
                                          waysAttributesQuery text,  -- liste des attributs de route à récupérer sous forme de requête
                                          where_clause text      -- clause WHERE pour la sélection d'une partie du graphe pour le routing
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
    node_lat double precision,  -- latitude du node (seulement si waypoint)
    edge_attributes text        -- ensemble des attributs à retourner (séparés par des &&)
    ) AS $$
  DECLARE
    graph_query text;
    final_query text;
  BEGIN
    -- création de la requete SQL
    -- -- requete pour avoir le graphe
    graph_query := concat('SELECT id,source,target, ', costname,' AS cost, ',
      rcostname,' AS reverse_cost FROM ways',
      where_clause
    );
    -- --
    -- -- requete sql complete
    final_query := concat('SELECT path.seq, path.path_seq, path.node::integer, path.edge::integer,
                            path.cost, path.agg_cost, ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom),
                            ST_Y(nodes.the_geom), ', waysAttributesQuery,'
                          FROM pgr_dijkstraVia($1, coordTableToVIDTable($2)) AS path
                          LEFT JOIN ways ON (path.edge = ways.id)
                          -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
                          LEFT JOIN ways_vertices_pgr AS nodes ON (path.node = nodes.id) AND (path.path_seq = 1 OR path.edge<0)
                          ORDER BY seq'
                  );
    -- --
    -- Execution de la requete
    RETURN QUERY EXECUTE final_query
      USING graph_query, coordinatesTable;
  END;
$$ LANGUAGE 'plpgsql' ;

-- A* entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_astar(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours (longueur 2)
                                       costname text,         -- nom de la colonne du coût
                                       rcostname text,        -- nom de la colonne de coût inverse
                                       waysAttributesQuery text,  -- liste des attributs de route à récupérer sous forme de requête
                                       where_clause text      -- clause WHERE pour la sélection d'une partie du graphe pour le routing
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
    node_lat double precision,  -- latitude du node (seulement si waypoint)
    edge_attributes text        -- ensemble des attributs à retourner (séparés par des &&)
    ) AS $$
  DECLARE
    vertex_ids_result integer[];
    start_vertex_id integer;
    end_vertex_id integer;
    graph_query text;
    final_query text;
  BEGIN
    vertex_ids_result := coordTableToVIDTable(coordinatesTable);
    start_vertex_id := vertex_ids_result[1];
    end_vertex_id := vertex_ids_result[2];

    -- création de la requete SQL
    -- -- requete pour avoir le graphe
    graph_query := concat('SELECT id::integer,source::integer,target::integer,x1,y1,x2,y2, ', costname,' AS cost, ',
      rcostname,' AS reverse_cost FROM ways',
      where_clause
    );
    -- --
    -- -- requete sql complete
    final_query := concat('SELECT path.seq, path.path_seq, path.node::integer, path.edge::integer,
                            path.cost, path.agg_cost, ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom),
                            ST_Y(nodes.the_geom), ', waysAttributesQuery,'
                          FROM pgr_aStar($1, $2, $3, true) AS path
                          LEFT JOIN ways ON (path.edge = ways.id)
                          -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
                          LEFT JOIN ways_vertices_pgr AS nodes ON (path.node = nodes.id) AND (path.path_seq = 1 OR path.edge<0)
                          ORDER BY seq'
                  );
    -- --
    -- Execution de la requete
    RETURN QUERY EXECUTE final_query
      USING graph_query, start_vertex_id, end_vertex_id;
  END;
$$ LANGUAGE 'plpgsql' ;

-- trsp entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_trspVertices(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                      costname text,         -- nom de la colonne du coût
                                      rcostname text,        -- nom de la colonne de coût inverse
                                      waysAttributesQuery text,  -- liste des attributs de route à récupérer sous forme de requête
                                      where_clause text      -- clause WHERE pour la sélection d'une partie du graphe pour le routing
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
    node_lat double precision,  -- latitude du node (seulement si waypoint)
    edge_attributes text        -- ensemble des attributs à retourner (séparés par des &&)
    ) AS $$
  #variable_conflict use_column
  DECLARE
  graph_query text;
  final_query text;
  BEGIN
    -- création de la requete SQL
    -- -- requete pour avoir le graphe
    graph_query := concat('SELECT id::integer,source::integer,target::integer, ', costname,' AS cost, ',
      rcostname,' AS reverse_cost FROM ways',
      where_clause
    );
    -- --
    -- -- requete sql complete
    -- Astuce pour pouvoir détecter le passage a un nouveau waypoint car comportement très différent
    -- des autres fonctions : pas de path_seq mais un id de la route => on utilise *-1
    final_query := concat('SELECT path.seq as seq, -1 * path.id1 as path_seq, path.id1 as node,
                            path.id2 as edge, path.cost as cost,
                            SUM(cost) OVER (ORDER BY seq ASC rows between unbounded preceding and current row) as agg_cost,
                            ST_AsGeoJSON(ways.the_geom), ST_X(nodes.the_geom),
                            ST_Y(nodes.the_geom), ', waysAttributesQuery,'
                          FROM pgr_trspViaVertices($1, coordTableToVIDTable($2), true, true) AS path
                          LEFT JOIN ways ON (path.id3 = ways.id)
                          -- Jointure uniquement si début de trajet entre 2 waypoints ou si dernière étape
                          LEFT JOIN ways_vertices_pgr AS nodes ON (path.id2 = nodes.id)
                          ORDER BY seq'
                  );
    -- --
    -- Execution de la requete
    RETURN QUERY EXECUTE final_query
      USING graph_query, coordinatesTable;
  END;
$$ LANGUAGE 'plpgsql' ;



-- Fonction finale, point d'entrée
----------------------------------------------------------------------------------------------------

-- fonction qui choisit la bonne fonction à executer
CREATE OR REPLACE FUNCTION shortest_path_with_algorithm(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                                        costname text,         -- nom de la colonne du coût
                                                        rcostname text,        -- nom de la colonne de coût inverse
                                                        algo text,             -- algorithme à utiliser
                                                        waysAttributes text[]  -- liste des attributs de route à récupérer
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
      node_lat double precision,  -- latitude du node (seulement si waypoint)
      edge_attributes text        -- ensemble des attributs à retourner (séparés par des &&)
      ) AS $$
  DECLARE
    coord_couples_table double precision[][][];
    m double precision[][];
    attributes_query text;
    where_clause text;
  BEGIN
    -- -- creation de la partie des attributs sur les chemins
    IF array_upper(waysAttributes, 1) > 1
    THEN
      attributes_query := concat('concat(ways.',waysAttributes[1]);
      FOR i in 2 .. array_upper(waysAttributes, 1)
      LOOP
        attributes_query := concat(attributes_query, ', ''§§'', ways.', waysAttributes[i]);
      END LOOP;
      attributes_query := concat(attributes_query,')');
    ELSIF array_upper(waysAttributes, 1) = 1
    THEN
      attributes_query := concat('ways.',waysAttributes[1]);
    ELSE
      RAISE 'waysAttributes invalid';
    END IF;

    where_clause := concat(' WHERE the_geom @ ( SELECT ST_Buffer( coordTableCentroid(''', coordinatesTable, ''' ),',
      1.5*farthestDistanceFromCentroid(coordinatesTable, coordTableCentroid(coordinatesTable)),
      ') )'
    );

    -- --
    -- -- choix de l'algo
    CASE algo
      WHEN 'dijkstra' THEN
        RETURN QUERY SELECT * FROM coord_dijkstra(coordinatesTable,costname,rcostname,attributes_query,where_clause) ;
      WHEN 'astar' THEN
        IF array_length(coordinatesTable, 1) > 2 THEN
          coord_couples_table := coordTableToCoordCouplesTable(coordinatesTable);
          FOREACH m SLICE 2 in ARRAY coord_couples_table
          LOOP
            RETURN QUERY SELECT * FROM coord_astar(m,costname,rcostname,attributes_query, where_clause) ;
          END LOOP;
        ELSE
          RETURN QUERY SELECT * FROM coord_astar(coordinatesTable,costname,rcostname,attributes_query, where_clause) ;
        END IF;
      WHEN 'trsp' THEN
        RETURN QUERY SELECT * FROM coord_trspVertices(coordinatesTable,costname,rcostname,attributes_query, where_clause) ;
      ELSE
        RETURN QUERY SELECT * FROM coord_dijkstra(coordinatesTable,costname,rcostname,attributes_query, where_clause) ;
    END CASE;
    -- --
  END ;
$$ LANGUAGE 'plpgsql' ;

-- Pour la retrocompatibilité avec le master de road2
-- TODO: supprimer !
CREATE OR REPLACE FUNCTION shortest_path_with_algorithm(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                                        costname text,         -- nom de la colonne du coût
                                                        rcostname text,        -- nom de la colonne de coût inverse
                                                        algo text
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
      node_lat double precision,  -- latitude du node (seulement si waypoint)
      edge_attributes text        -- ensemble des attributs à retourner (séparés par des &&)
      ) AS $$
  BEGIN
    RETURN QUERY SELECT * FROM shortest_path_with_algorithm(coordinatesTable, -- table des points dans l'ordre de parcours
                                                          costname ,         -- nom de la colonne du coût
                                                          rcostname ,        -- nom de la colonne de coût inverse
                                                          algo,
                                                          array ['way_names']
                                                          ) ;
  END ;

$$ LANGUAGE 'plpgsql';
