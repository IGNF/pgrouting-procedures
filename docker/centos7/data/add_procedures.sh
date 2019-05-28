#!/bin/bash

#Version
PG_VERSION="10"

#Settings
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

PG_PORT=5432
PG_CONFDIR="/var/lib/pgsql/$PG_VERSION/data"
PG_CTL="/usr/pgsql-$PG_VERSION/bin/pg_ctl"
PG_USER="postgres"
PSQL="/bin/psql"

add_procedures() {
  ## Extract from https://github.com/CentOS/CentOS-Dockerfiles/blob/master/postgres/centos7/
  ## and modified by me
  ##
  ## Check to see if we have pre-defined credentials to use
  if [ -n "${DB_NAME}" ]; then
    # run postgresql server
    cd /var/lib/pgsql && bash -c "$PG_CTL -D $PG_CONFDIR -o \"-c listen_addresses='*'\" -w start"

    echo "Installing procedures on \"${DB_NAME}\"..."
    $PSQL ${DB_NAME} -U $PG_USER -c "CREATE TABLE ways(
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
            way_names text
        );"
    $PSQL ${DB_NAME} -U $PG_USER -c "CREATE TABLE ways_vertices_pgr(
            id bigserial unique,
            cnt int,
            chk int,
            ein int,
            eout int,
            the_geom geometry(Point,4326)
        );"
    $PSQL ${DB_NAME} -U $PG_USER -a -f /usr/local/bin/dijkstra.sql

    # stop postgresql server
    bash -c "$PG_CTL -D $PG_CONFDIR -m fast -w stop"

  fi
}

####
####
add_procedures

