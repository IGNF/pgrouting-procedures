#!/bin/sh

#define parameters which are passed in.
SCHEMA=$1

#define the template.
cat  << EOF
-- Fonctions utilitaires
----------------------------------------------------------------------------------------------------

-- Conversion de coordinatesTable vers edgeIdTable
CREATE OR REPLACE FUNCTION $SCHEMA.coordTableToEIDTable(coordinatesTable double precision[][],
                                                costname text,         -- nom de la colonne du coût
                                                rcostname text,        -- nom de la colonne de coût inverse
                                                where_clause text
                                                )
  RETURNS integer[] AS \$\$
  DECLARE
    i integer;
    result integer[] DEFAULT '{}';
    edgeId integer;
  BEGIN
    FOR i in 1 .. array_upper(coordinatesTable, 1)
    LOOP
      edgeId := $SCHEMA.nearest_edge(coordinatesTable[i][1], coordinatesTable[i][2], costname, rcostname, where_clause) ;
      result := array_append(result, edgeId) ;
    END LOOP;
    RETURN result;
  END ;
\$\$ LANGUAGE 'plpgsql' ;


-- Conversion de coordinatesTable vers fractionTable
CREATE OR REPLACE FUNCTION $SCHEMA.coordTableToFractionTable(coordinatesTable double precision[][],
                                                     costname text,         -- nom de la colonne du coût
                                                     rcostname text,        -- nom de la colonne de coût inverse
                                                     where_clause text
                                                     )
  RETURNS float[] AS \$\$
  DECLARE
    i integer;
    frac float;
    result float[] DEFAULT '{}';
    edgeIdTable integer[];
    lon double precision;
    lat double precision;
  BEGIN
    edgeIdTable := $SCHEMA.coordTableToEIDTable(coordinatesTable, costname, rcostname, where_clause);
    FOR i in 1 .. array_upper(edgeIdTable, 1)
    LOOP
      lon := coordinatesTable[i][1] ;
      lat := coordinatesTable[i][2] ;
      frac := ST_LineLocatePoint( (SELECT the_geom FROM $SCHEMA.ways WHERE id=edgeIdTable[i]), st_setsrid(st_makepoint(lon,lat),4326)  ) ;
      result := array_append(result, frac) ;
    END LOOP;
    RETURN result;
  END ;
\$\$ LANGUAGE 'plpgsql' ;


-- Fonction de routing
----------------------------------------------------------------------------------------------------

-- trsp (edges) entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION $SCHEMA.coord_trspEdges(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                      profile_name text,     -- nom du profil utilisé
                                      costname text,         -- nom de la colonne du coût
                                      rcostname text,        -- nom de la colonne de coût inverse
                                      waysAttributesQuery text,  -- liste des attributs de route à récupérer sous forme de requête
                                      where_clause text,      -- clause WHERE pour la sélection d'une partie du graphe pour le routing
                                      real_cost_name text,   -- "vrai" nom du coût dans le cas de contraintes préférentielles
                                      real_rcost_name text    -- "vrai" nom du coût inverse dans le cas de contraintes préférentielles
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
    ) AS \$\$
  #variable_conflict use_column
  DECLARE
  graph_query text;
  final_query text;
  restrict_sql text;
  BEGIN
    -- création de la requete SQL
    -- -- requete pour avoir le graphe
    graph_query := concat('SELECT id::integer,source::integer,target::integer, ', costname,' AS cost, ',
      rcostname,' AS reverse_cost FROM $SCHEMA.ways AS tempways',
      where_clause
    );
    restrict_sql := 'SELECT 2000::double precision as to_cost, id_to::integer as target_id, id_from::text as via_path FROM $SCHEMA.turn_restrictions';
    -- --
    -- -- requete sql complete
    -- Astuce pour pouvoir détecter le passage a un nouveau waypoint car comportement très différent
    -- des autres fonctions : pas de path_seq mais un id de la route => on utilise *-1
    final_query := concat('SELECT path.seq as seq, -1 * path.id1 as path_seq, path.id2 as node,
                            path.id3 as edge, path.cost as cost,
                            SUM(cost) OVER (ORDER BY seq ASC rows between unbounded preceding and current row) as agg_cost,
                            CASE
                              WHEN path.id2 = $SCHEMA.ways.source OR (LEAD(path.id2) OVER (ORDER BY seq ASC)) = $SCHEMA.ways.target
                              THEN ST_AsGeoJSON($SCHEMA.ways.the_geom,6)
                              ELSE ST_AsGeoJSON(ST_Reverse($SCHEMA.ways.the_geom),6)
                            END,',
                            'CASE
                              WHEN $SCHEMA.ways.', real_cost_name, ' > 0 THEN',
                            '   $SCHEMA.ways.cost_m_', profile_name,
                            ' ELSE
                                $SCHEMA.ways.reverse_cost_m_', profile_name,'
                            END as distance,',
                            'CASE
                              WHEN $SCHEMA.ways.', real_cost_name, ' > 0 THEN',
                            '   $SCHEMA.ways.cost_s_', profile_name,
                            ' ELSE
                                $SCHEMA.ways.reverse_cost_s_', profile_name,'
                             END as duration,',
                            waysAttributesQuery,'
                          FROM pgr_trspViaEdges(\$1, $SCHEMA.coordTableToEIDTable(\$2,\$niv2\$',real_cost_name,'\$niv2\$,\$niv2\$',real_rcost_name,'\$niv2\$,\$niv2\$',where_clause,'\$niv2\$),
                            $SCHEMA.coordTableToFractionTable(\$2,\$niv2\$',real_cost_name,'\$niv2\$,\$niv2\$',real_rcost_name,'\$niv2\$,\$niv2\$',where_clause,'\$niv2\$), true, true,
                            \$3)
                          AS path
                          LEFT JOIN $SCHEMA.ways ON (path.id3 = $SCHEMA.ways.id)
                          ORDER BY seq'
                  );
    -- --
    -- Execution de la requete
    RETURN QUERY EXECUTE final_query
      USING graph_query, coordinatesTable, restrict_sql;
  END;
\$\$ LANGUAGE 'plpgsql' ;


-- Point d'entrée
----------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION $SCHEMA.shortest_path_pgrouting(coordinatesTable double precision[][], -- table des points dans l'ordre de parcours
                                                        profile_name text,     -- nom du profil utilisé
                                                        costname text,         -- nom de la colonne du coût
                                                        rcostname text,        -- nom de la colonne de coût inverse
                                                        waysAttributes text[], -- liste des attributs de route à récupérer
                                                        constraints text       -- contraintes au format SQL
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
      ) AS \$\$
  DECLARE
    coord_couples_table double precision[][][];
    m double precision[][];
    attributes_query text;
    where_clause text;
    eidtable integer[];
    costname_array text[];
    rcostname_array text[];
    real_cost_name text;
    real_rcost_name text;
    else_position integer;
  BEGIN
    -- -- creation de la partie des attributs sur les chemins
    IF array_upper(waysAttributes, 1) > 1
    THEN
      attributes_query := concat('concat($SCHEMA.ways.',waysAttributes[1]);
      FOR i in 2 .. array_upper(waysAttributes, 1)
      LOOP
        attributes_query := concat(attributes_query, ', ''§§'', $SCHEMA.ways.', waysAttributes[i]);
      END LOOP;
      attributes_query := concat(attributes_query,')');
    ELSIF array_upper(waysAttributes, 1) = 1
    THEN
      attributes_query := concat('$SCHEMA.ways.',waysAttributes[1]);
    ELSIF waysAttributes = '{}'
    THEN
      attributes_query := 'null';
    ELSE
      RAISE 'waysAttributes invalid';
    END IF;

    real_cost_name := costname;
    real_rcost_name := rcostname;
    SELECT string_to_array(costname, ' ') INTO costname_array;
    SELECT string_to_array(rcostname, ' ') INTO rcostname_array;
    else_position := 0;
    -- si contraintes préférentielles : récupération du 'vrai' nom du coût
    IF array_upper(costname_array, 1) > 1
    THEN
      FOR i in 1 .. array_upper(costname_array, 1)
      LOOP
        IF costname_array[i] = 'ELSE'
        THEN
          else_position := i;
          EXIT;
        END IF;
      END LOOP;
      real_cost_name := costname_array[else_position + 1];
    END IF;
    IF array_upper(rcostname_array, 1) > 1
    THEN
      FOR i in 1 .. array_upper(rcostname_array, 1)
      LOOP
        IF rcostname_array[i] = 'ELSE'
        THEN
          else_position := i;
          EXIT;
        END IF;
      END LOOP;
      real_rcost_name := rcostname_array[else_position + 1];
    END IF;
    -- --
    eidtable := $SCHEMA.coordTableToEIDTable( coordinatesTable, real_cost_name, real_rcost_name, 'WHERE TRUE' );

    where_clause := concat(' WHERE (importance=''1'' OR (the_geom && (SELECT ST_Expand( ST_Extent(the_geom), 0.1 ) FROM $SCHEMA.ways WHERE id = ANY(\$niv3\$', eidtable, '\$niv3\$::int[]))))');
    -- where_clause := '';
    IF constraints != ''
    THEN
      where_clause := concat(where_clause, ' AND ', constraints);
    END IF;
    -- --
    RETURN QUERY SELECT * FROM $SCHEMA.coord_trspEdges(coordinatesTable,profile_name,costname,rcostname,attributes_query,where_clause,real_cost_name,real_rcost_name) ;
    -- --
  END ;
\$\$ LANGUAGE 'plpgsql' ;
EOF
