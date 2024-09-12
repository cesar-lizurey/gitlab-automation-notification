#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

docker compose -f $SCRIPT_DIR/docker-compose.yml down --rmi all
docker compose -f $SCRIPT_DIR/docker-compose.yml up -d
