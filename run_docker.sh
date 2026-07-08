#!/bin/bash

# Load environment variables from .env.local
echo "Loading env variables from './.env.local'"
set -o allexport
source ./.env.local
set -o allexport -

echo "Killing old Docker processes"
docker compose rm -fs

echo "Spinning up Docker containers"
docker compose -f docker-compose-ssl.yml build && \
docker compose -f docker-compose-ssl.yml up --detach && \
docker compose -f docker-compose-ssl.yml logs --follow
