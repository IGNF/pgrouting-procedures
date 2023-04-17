#!/bin/bash

#suppose l'existence du contenu de ../sql_templates dans /usr/local/bin/
SCHEMA='public'

PG_PORT=5432
PG_USER="postgres"
DB_NAME="pgrouting"

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "postgres" <<-EOSQL
    CREATE DATABASE $DB_NAME WITH ENCODING 'UTF8' TEMPLATE template0;
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME to $PG_USER;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "postgres" <<-EOSQL
    CREATE DATABASE pivot WITH ENCODING 'UTF8' TEMPLATE template0;
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME to $PG_USER;
EOSQL

psql $DB_NAME -U $PG_USER -c "CREATE SCHEMA IF NOT EXISTS $SCHEMA;"

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "$DB_NAME" <<-EOSQL
    CREATE EXTENSION postgis;
    CREATE EXTENSION pgrouting;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "pivot" <<-EOSQL
    CREATE EXTENSION postgis;
    CREATE EXTENSION postgres_fdw;
EOSQL


echo "Installing procedures on \"$DB_NAME\" schema $SCHEMA..."
psql $DB_NAME -U $PG_USER -c "CREATE TABLE $SCHEMA.ways(
        id bigserial unique,
        tag_id integer,
        length double precision,
        length_m double precision,
        name text,
        source bigint,
        target bigint,
        rule text,
        one_way int ,
        oneway TEXT ,
        x1 double precision,
        y1 double precision,
        x2 double precision,
        y2 double precision,
        maxspeed_forward double precision,
        maxspeed_backward double precision,
        priority double precision DEFAULT 1,
        the_geom geometry(Linestring,4326),
        way_names text,
        nature text,
        vitesse_moyenne_vl text,
        position_par_rapport_au_sol integer,
        acces_vehicule_leger text,
        largeur_de_chaussee double precision,
        nombre_de_voies text,
        insee_commune_gauche text,
        insee_commune_droite text,
        bande_cyclable text,
        itineraire_vert boolean,
        reserve_aux_bus text,
        urbain boolean,
        acces_pieton text,
        nature_de_la_restriction text,
        restriction_de_hauteur text,
        restriction_de_poids_total text,
        restriction_de_poids_par_essieu text,
        restriction_de_largeur text,
        restriction_de_longueur text,
        matieres_dangereuses_interdites boolean,
        cpx_gestionnaire text,
        cpx_numero_route_europeenne text,
        cpx_classement_administratif text
    );"
psql $DB_NAME -U $PG_USER -c "CREATE TABLE $SCHEMA.ways_vertices_pgr(
        id bigserial unique,
        cnt int,
        chk int,
        ein int,
        eout int,
        the_geom geometry(Point,4326)
    );"

bash /usr/local/bin/generate_utilities.sh $SCHEMA > /usr/local/bin/utilities.sql
bash /usr/local/bin/generate_routeProcedures.sh $SCHEMA > /usr/local/bin/routeProcedures.sql
bash /usr/local/bin/generate_isochroneProcedures.sh $SCHEMA > /usr/local/bin/isochroneProcedures.sql
psql $DB_NAME -U $PG_USER -a -f /usr/local/bin/routeProcedures.sql
psql $DB_NAME -U $PG_USER -a -f /usr/local/bin/utilities.sql
psql $DB_NAME -U $PG_USER -a -f /usr/local/bin/isochroneProcedures.sql
