-- Arc du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_edge(lon double precision,
                                        lat double precision,
                                        costname text,         -- nom de la colonne du coût
                                        rcostname text,        -- nom de la colonne de coût inverse
                                        where_clause text
                                        )
  RETURNS integer AS $$
  DECLARE
    result integer;
    final_query text;
  BEGIN
    final_query := concat('SELECT id::integer
      FROM ways
      ', where_clause, ' AND (', costname, ' > 0 OR ', rcostname, ' > 0)
      ORDER BY the_geom <-> st_setsrid(st_makepoint(',lon,',',lat,'),4326)
      LIMIT 1 ') ;
    EXECUTE final_query INTO result ;
    RETURN result ;
  END ;
$$ LANGUAGE 'plpgsql' ;

-- Noeud du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_node(lon double precision,
                                        lat double precision,
                                        costname text,         -- nom de la colonne du coût
                                        rcostname text,        -- nom de la colonne de coût inverse
                                        where_clause text
                                        )
  RETURNS integer AS $$
  DECLARE
    result integer;
    final_query text;
  BEGIN
    final_query := concat('SELECT source::integer
      FROM ways
      ', where_clause, ' AND (', costname, ' > 0 OR ', rcostname, ' > 0)
      ORDER BY the_geom <-> st_setsrid(st_makepoint(',lon,',',lat,'),4326)
      LIMIT 1 ') ;
    EXECUTE final_query INTO result ;
    RETURN result ;
  END ;
$$ LANGUAGE 'plpgsql';

-- nettoie le graphe : donne un coût négatif aux arc isolés par rapport à la composante connexe principale
CREATE OR REPLACE FUNCTION clean_graph(
    profile_name text -- Nom du profil à nettoyer
  )
  RETURNS void AS $$
  DECLARE
    isolated integer[];
    node_id integer;
    connected_component_query text;
    update_query text;
  BEGIN
    connected_component_query := concat(
      'SELECT id,
      source,
      target,
      cost_s_', profile_name,' as cost,
      reverse_cost_s_', profile_name,' as reverse_cost
      from ways'
    );

    isolated := ARRAY(
      WITH biggest_component AS
        (
          SELECT component AS name, count(*) AS nb
          FROM
            pgr_connectedComponents(connected_component_query)
          GROUP BY component
          ORDER BY nb DESC
          LIMIT 1
        )
      SELECT node
      FROM
        pgr_connectedComponents(
          connected_component_query
        ),
        biggest_component
      WHERE
      component != biggest_component.name
    );

  update_query := concat('UPDATE ways
    SET cost_s_', profile_name,' = -1,
      cost_m_', profile_name,' = -1,
      reverse_cost_s_', profile_name,' = -1,
      reverse_cost_m_', profile_name,' = -1
    WHERE ways.target = ANY(''', isolated, ''') OR ways.source = ANY(''', isolated, ''');'
  );
  EXECUTE update_query;
  END;
$$ LANGUAGE 'plpgsql' ;
