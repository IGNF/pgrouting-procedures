#!/bin/bash

PG_PORT=5432

postgresql_server () {
  /usr/local/pgsql/bin/postgres -D /usr/local/pgsql/data -p $PG_PORT
}

####
####
echo "Starting PostgreSQL server..."
postgresql_server
