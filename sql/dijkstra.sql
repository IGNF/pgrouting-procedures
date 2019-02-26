-- Point du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_node(lat double precision, lon double precision) RETURNS bigint AS $$
  SELECT id
  FROM ways_vertices_pgr
  ORDER BY the_geom <-> st_setsrid(st_makepoint(lon,lat),4326)
  LIMIT 1
$$ LANGUAGE SQL ;



-- Dijskstra entre lat1 lon1 et lat2 lon2
CREATE OR REPLACE FUNCTION coord_dijskstra(lat1 double precision,
                                           lon1 double precision,
                                           lat2 double precision,
                                           lon2 double precision,
                                           costname text,
                                           rcostname text)
  RETURNS TABLE (
    seq int,
    path_seq int,
    node bigint,
    edge bigint,
    cost double precision,
    agg_cost double precision,
    geom_json text
    ) AS $$
  SELECT path.*, ST_AsGeoJSON(ways.the_geom) FROM pgr_dijkstra(concat('SELECT id,source,target,',
                                                                       costname,
                                                                       ' AS cost,',
                                                                       rcostname,
                                                                       ' AS reverse_cost FROM ways'
                                                                       ),
                                                                nearest_node(lat1,lon1),
                                                                nearest_node(lat2,lon2))
                                                  AS path
  LEFT JOIN ways ON (path.edge = ways.id)
  ORDER BY seq
$$ LANGUAGE SQL ;
