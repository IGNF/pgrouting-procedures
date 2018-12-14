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

create_dbuser() {
  ## Extract from https://github.com/CentOS/CentOS-Dockerfiles/blob/master/postgres/centos7/
  ## and modified by me
  ##
  ## Check to see if we have pre-defined credentials to use
  if [ -n "${DB_USER}" ]; then

    # run postgresql server
    cd /var/lib/pgsql && sudo -u $PG_USER bash -c "$PG_CTL -D $PG_CONFDIR -o \"-c listen_addresses='*'\" -w start"
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
    sudo -u $PG_USER bash -c "echo \"host    all             all             0.0.0.0/0               md5\" >> $PG_CONFDIR/pg_hba.conf"

  else
    # the user is not created set authentication method to trust
    sudo -u $PG_USER bash -c "echo \"host    all             all             0.0.0.0/0               trust\" >> $PG_CONFDIR/pg_hba.conf"
  fi

  if [ -n "${DB_NAME}" ]; then

    # create database
    echo "Creating database \"${DB_NAME}\"..."
    echo "CREATE DATABASE ${DB_NAME};"
    $PSQL -U $PG_USER -c "CREATE DATABASE ${DB_NAME}"
    # grant permission
    if [ -n "${DB_USER}" ]; then
      echo "Granting access to database \"${DB_NAME}\" for user \"${DB_USER}\"..."
      $PSQL -U $PG_USER -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USER};"
    fi

    # stop postgresql server
    sudo -u $PG_USER bash -c "$PG_CTL -D $PG_CONFDIR -m fast -w stop"

  fi
}


postgresql_server () {

  /usr/pgsql-$PG_VERSION/bin/postgres -D /var/lib/pgsql/$PG_VERSION/data -p $PG_PORT
}

####
####
create_dbuser
echo "Starting PostgreSQL $PG_VERSION server..."
postgresql_server
