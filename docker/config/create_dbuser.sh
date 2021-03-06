#!/bin/bash

#Settings
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

PG_PORT=5432
PG_CONFDIR="/usr/local/pgsql/data"
PG_CTL="/usr/local/pgsql/bin/pg_ctl"
PG_USER="postgres"
PSQL="/usr/local/pgsql/bin/psql"

create_dbuser() {
  ## Extract from https://github.com/CentOS/CentOS-Dockerfiles/blob/master/postgres/centos7/
  ## and modified by me
  ##
  ## Check to see if we have pre-defined credentials to use
  if [ -n "${DB_USER}" ]; then

    # run postgresql server
    cd /usr/local/pgsql/ && bash -c "$PG_CTL -D $PG_CONFDIR -o \"-c listen_addresses='*'\" -w start"
    # generate password
    if [ -z "${DB_PASS}" ]; then
      echo "WARNING: "
      echo "No password specified for \"${DB_USER}\". Generating one"
      DB_PASS=$(pwgen -c -n -1 12)
      echo "Password for \"${DB_USER}\" created as: \"${DB_PASS}\""
    fi
    # create user
    echo "Creating user \"${DB_USER}\"..."
    $PSQL -U $PG_USER -c "CREATE ROLE ${DB_USER} with CREATEROLE login superuser PASSWORD '${DB_PASS}';"
    # if the user is already created set authentication method to md5
    bash -c "echo \"host    all             all             0.0.0.0/0               md5\" >> $PG_CONFDIR/pg_hba.conf"

    # stop postgresql server
    bash -c "$PG_CTL -D $PG_CONFDIR -m fast -w stop"

  else
    # the user is not created set authentication method to trust
    bash -c "echo \"host    all             all             0.0.0.0/0               trust\" >> $PG_CONFDIR/pg_hba.conf"
  fi

  if [ -n "${DB_NAME}" ]; then
    # run postgresql server
    cd /usr/local/pgsql/ && bash -c "$PG_CTL -D $PG_CONFDIR -o \"-c listen_addresses='*'\" -w start"

    # create database
    echo "Creating database \"${DB_NAME}\"..."
    echo "CREATE DATABASE ${DB_NAME} WITH ENCODING 'UTF8' TEMPLATE template0;"
    $PSQL -U $PG_USER -c "CREATE DATABASE ${DB_NAME} WITH ENCODING 'UTF8' TEMPLATE template0"
    echo "Adding postgis and pgrouting extentions to \"${DB_NAME}\"..."
    $PSQL ${DB_NAME} -U $PG_USER -c "CREATE EXTENSION postgis"
    $PSQL ${DB_NAME} -U $PG_USER -c "CREATE EXTENSION pgrouting"
    $PSQL ${DB_NAME} -U $PG_USER -c "CREATE EXTENSION postgres_fdw"
    # grant permission
    if [ -n "${DB_USER}" ]; then
      echo "Granting access to database \"${DB_NAME}\" for user \"${DB_USER}\"..."
      $PSQL -U $PG_USER -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USER};"
    fi

    # stop postgresql server
    bash -c "$PG_CTL -D $PG_CONFDIR -m fast -w stop"

  fi
}

####
####
create_dbuser

