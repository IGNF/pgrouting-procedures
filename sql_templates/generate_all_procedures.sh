#!/bin/sh

#define parameters which are passed in.
SCHEMA=$1

./generate_utilities.sh $SCHEMA && ./generate_isochroneProcedures.sh $SCHEMA && ./generate_routeProcedures.sh $SCHEMA
