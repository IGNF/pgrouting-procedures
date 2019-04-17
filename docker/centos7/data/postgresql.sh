#!/bin/bash

#Version
PG_VERSION="10"

PG_PORT=5432

postgresql_server () {
  /usr/pgsql-$PG_VERSION/bin/postgres -D /var/lib/pgsql/$PG_VERSION/data -p $PG_PORT
}

####
####
echo "Starting PostgreSQL $PG_VERSION server..."
postgresql_server
