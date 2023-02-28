#!/bin/bash

#suppose l'existence du contenu de ../sql_templates dans /usr/local/bin/

SCHEMA="public"

PG_HOST="localhost"
PG_PORT=5432
PG_USER="postgres"
DB_NAME="pgrouting"

CREATE_DBS=True

TEMPLATES_DIR=/usr/local/bin
WORK_DIR=/usr/local/bin

while [ True ]; do
    if [ "$1" = "--schema" -o "$1" = "-s" ]; then
        SCHEMA=$2
        shift 2
    elif [ "$1" = "--hote" -o "$1" = "-h" ]; then
        PG_HOST=$2
        shift 2
    elif [ "$1" = "--port" -o "$1" = "-p" ]; then
        PG_PORT=$2
        shift 2
    elif [ "$1" = "--user" -o "$1" = "-u" ]; then
        PG_USER=$2
        shift 2
    elif [ "$1" = "--dbname" -o "$1" = "-d" ]; then
        DB_NAME=$2
        shift 2
    elif [ "$1" = "--no-create-dbs" -o "$1" = "-ndbs" ]; then
        CREATE_DBS=False
        shift 1
    elif [ "$1" = "--templates-dir" -o "$1" = "-td" ]; then
        TEMPLATES_DIR=$2
        shift 2
    elif [ "$1" = "--work-dir" -o "$1" = "-wd" ]; then
        WORK_DIR=$2
        shift 2
    else
        break
    fi
done


if [ $CREATE_DBS ]; then

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "postgres" --host "$PG_HOST" --port $PG_PORT <<-EOSQL
    CREATE DATABASE $DB_NAME WITH ENCODING 'UTF8' TEMPLATE template0;
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME to $PG_USER;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "postgres" --host "$PG_HOST" --port $PG_PORT <<-EOSQL
    CREATE DATABASE pivot WITH ENCODING 'UTF8' TEMPLATE template0;
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME to $PG_USER;
EOSQL

psql $DB_NAME -U $PG_USER - -c "CREATE SCHEMA IF NOT EXISTS $SCHEMA;"

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "$DB_NAME" --host "$PG_HOST" --port $PG_PORT <<-EOSQL
    CREATE EXTENSION postgis;
    CREATE EXTENSION pgrouting;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$PG_USER" --dbname "pivot" --host "$PG_HOST" --port $PG_PORT <<-EOSQL
    CREATE EXTENSION postgis;
    CREATE EXTENSION postgres_fdw;
EOSQL

fi


echo "Installing procedures on \"$DB_NAME\" schema $SCHEMA..."
psql $DB_NAME -U $PG_USER --host "$PG_HOST" --port $PG_PORT -c "CREATE TABLE $SCHEMA.ways(
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
psql $DB_NAME -U $PG_USER --host "$PG_HOST" --port $PG_PORT -c "CREATE TABLE $SCHEMA.ways_vertices_pgr(
        id bigserial unique,
        cnt int,
        chk int,
        ein int,
        eout int,
        the_geom geometry(Point,4326)
    );"

bash $TEMPLATES_DIR/generate_utilities.sh $SCHEMA > $WORK_DIR/utilities.sql
bash $TEMPLATES_DIR/generate_routeProcedures.sh $SCHEMA > $WORK_DIR/routeProcedures.sql
bash $TEMPLATES_DIR/generate_isochroneProcedures.sh $SCHEMA > $WORK_DIR/isochroneProcedures.sql
psql $DB_NAME -U $PG_USER --host "$PG_HOST" --port $PG_PORT -a -f $WORK_DIR/utilities.sql
psql $DB_NAME -U $PG_USER --host "$PG_HOST" --port $PG_PORT -a -f $WORK_DIR/routeProcedures.sql
psql $DB_NAME -U $PG_USER --host "$PG_HOST" --port $PG_PORT -a -f $WORK_DIR/isochroneProcedures.sql
