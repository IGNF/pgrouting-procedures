-- Fonctions utilitaires
----------------------------------------------------------------------------------------------------

-- Arc du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_edge(lon double precision,
                                        lat double precision,
                                        costname text,         -- nom de la colonne du coût
                                        rcostname text        -- nom de la colonne de coût inverse
                                        )
  RETURNS integer AS $$
  DECLARE
    result integer;
    final_query text;
  BEGIN
    final_query := concat('SELECT id::integer
      FROM ways
      -- WHERE ST_DWithin(Geography(st_setsrid(st_makepoint(lon,lat),4326)),Geography(the_geom),1000)
      WHERE ', costname, ' > 0 OR ', rcostname, ' > 0
      ORDER BY the_geom <-> st_setsrid(st_makepoint(',lon,',',lat,'),4326)
      LIMIT 1 ') ;
    EXECUTE final_query INTO result ;
    RETURN result ;
  END ;
$$ LANGUAGE 'plpgsql' ;

-- Conversion de coordinatesTable vers edgeIdTable
CREATE OR REPLACE FUNCTION coordTableToEIDTable(coordinatesTable double precision[][],
                                                costname text,         -- nom de la colonne du coût
                                                rcostname text        -- nom de la colonne de coût inverse
                                                )
  RETURNS integer[] AS $$
  DECLARE
    i integer;
    result integer[] DEFAULT '{}';
    edgeId integer;
  BEGIN
    FOR i in 1 .. array_upper(coordinatesTable, 1)
    LOOP
      edgeId := nearest_edge(coordinatesTable[i][1], coordinatesTable[i][2], costname, rcostname) ;
      result := array_append(result, edgeId) ;
    END LOOP;
    RETURN result;
  END ;
$$ LANGUAGE 'plpgsql' ;


-- Conversion de coordinatesTable vers fractionTable
CREATE OR REPLACE FUNCTION coordTableToFractionTable(coordinatesTable double precision[][],
                                                     costname text,         -- nom de la colonne du coût
                                                     rcostname text        -- nom de la colonne de coût inverse
                                                     )
  RETURNS float[] AS $$
  DECLARE
    i integer;
    frac float;
    result float[] DEFAULT '{}';
    edgeIdTable integer[];
    lon double precision;
    lat double precision;
  BEGIN
    edgeIdTable := coordTableToEIDTable(coordinatesTable, costname, rcostname);
    FOR i in 1 .. array_upper(edgeIdTable, 1)
    LOOP
      lon := coordinatesTable[i][1] ;
      lat := coordinatesTable[i][2] ;
      frac := ST_LineLocatePoint( (SELECT the_geom FROM ways WHERE id=edgeIdTable[i]), st_setsrid(st_makepoint(lon,lat),4326)  ) ;
      result := array_append(result, frac) ;
    END LOOP;
    RETURN result;
  END ;
$$ LANGUAGE 'plpgsql' ;


-- Point sur une linestring à partir d'un point pas dans le graphe
CREATE OR REPLACE FUNCTION projectedPoint(lon double precision, lat double precision) RETURNS geometry AS $$
  DECLARE
    road_geom geometry;
  BEGIN
    SELECT INTO road_geom the_geom FROM ways WHERE id=nearest_edge(lon, lat);
    RETURN ST_LineInterpolatePoint(road_geom, ST_LineLocatePoint(road_geom, st_setsrid(st_makepoint(lon,lat),4326))) ;
  END ;
$$ LANGUAGE 'plpgsql' ;


-- Conversion de coordinatesTable vers centroid
CREATE OR REPLACE FUNCTION coordTableCentroid(coordinatesTable double precision[][]) RETURNS geometry AS $$
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
    result := ST_Centroid(Geography(multigeom))::geometry ;
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


-- Fonction de routing
----------------------------------------------------------------------------------------------------

-- trsp (edges) entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_trspEdges(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                      profile_name text,     -- nom du profil utilisé
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
    distance double precision, -- longueur du tronçon
    duration double precision,      -- durée du tronçon
    edge_attributes text        -- ensemble des attributs à retourner (séparés par des §§)
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
    final_query := concat('SELECT path.seq as seq, -1 * path.id1 as path_seq, path.id2 as node,
                            path.id3 as edge, path.cost as cost,
                            SUM(cost) OVER (ORDER BY seq ASC rows between unbounded preceding and current row) as agg_cost,
                            CASE
                              WHEN path.id2 = ways.source OR (LEAD(path.id2) OVER (ORDER BY seq ASC)) = ways.target
                              THEN ST_AsGeoJSON(ways.the_geom,6)
                              ELSE ST_AsGeoJSON(ST_Reverse(ways.the_geom),6)
                            END,',
                            'CASE
                              WHEN ways.', costname, ' > 0 THEN',
                            '   ways.cost_m_', profile_name,
                            ' ELSE
                                ways.reverse_cost_m_', profile_name,
                            ' END as distance,',
                            'CASE
                              WHEN ways.', costname, ' > 0 THEN',
                            '   ways.cost_s_', profile_name,
                            ' ELSE
                                ways.reverse_cost_s_', profile_name,'
                             END as duration,',
                            waysAttributesQuery,'
                          FROM pgr_trspViaEdges($1, coordTableToEIDTable($2,''',costname,''',''',rcostname,'''), coordTableToFractionTable($2,''',costname,''',''',rcostname,'''), true, true) AS path
                          LEFT JOIN ways ON (path.id3 = ways.id)
                          ORDER BY seq'
                  );
    -- --
    -- Execution de la requete
    RETURN QUERY EXECUTE final_query
      USING graph_query, coordinatesTable;
  END;
$$ LANGUAGE 'plpgsql' ;


-- Point d'entrée
----------------------------------------------------------------------------------------------------

-- TODO: enlever paramètre algo + renommer la fonction
CREATE OR REPLACE FUNCTION shortest_path_with_algorithm(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                                        profile_name text,     -- nom du profil utilisé
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
      agg_cost double precision,  -- coût aggrégé
      geom_json text,             -- géométrie en geojson de l'edge
      distance double precision, -- longueur du tronçon
      duration double precision,      -- durée du tronçon
      edge_attributes text        -- ensemble des attributs à retourner (séparés par des §§)
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
    ELSIF waysAttributes = '{}'
    THEN
      attributes_query := 'null';
    ELSE
      RAISE 'waysAttributes invalid';
    END IF;

    where_clause := concat(' WHERE the_geom && (SELECT ST_Expand( ST_Extent(the_geom), 0.1 ) FROM ways WHERE id = ANY(''', coordTableToEIDTable( coordinatesTable, costname, rcostname ), '''::int[]))');
    -- where_clause := '';
    -- --
    RETURN QUERY SELECT * FROM coord_trspEdges(coordinatesTable,profile_name,costname,rcostname,attributes_query, where_clause) ;
    -- --
  END ;
$$ LANGUAGE 'plpgsql' ;
