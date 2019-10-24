-- Noeud du graphe le plus proche d'un couple de cordonnées
CREATE OR REPLACE FUNCTION nearest_node(lon double precision, lat double precision) RETURNS integer AS $$
  DECLARE
    result integer;
  BEGIN
    SELECT INTO result id::integer
    FROM ways_vertices_pgr
    -- WHERE the_geom && (SELECT ST_Expand( ST_Extent(st_setsrid(st_makepoint(lon,lat),4326)),0.01))
    ORDER BY the_geom <-> st_setsrid(st_makepoint(lon, lat), 4326)
    LIMIT 1 ;
    RETURN result;
  END ;
$$ LANGUAGE 'plpgsql';
