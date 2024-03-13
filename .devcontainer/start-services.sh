#!/bin/sh

mkdir -p log

docker-compose -f docker-compose-deps.yml up &
timeout 90 sh -c 'until pg_isready -h localhost -p 54320; do sleep 1; done'

POSTGRES_CONTAINER=$( docker ps|grep postgis|awk '{print $1}' )
POSTGRES_UID=$(docker exec -it ${POSTGRES_CONTAINER} id -u postgres | tr -d '\r' )

./bin/setup
docker-compose -f docker-compose-deps.yml down

nohup bash -c 'docker-compose -f docker-compose-deps.yml up >> log/deps.log 2>&1 &'
# Wait for postgres to be ready.
timeout 90 sh -c 'until pg_isready -h localhost -p 54320; do sleep 1; done'

# Ensure permissions are set correctly for postgres user in container.
echo "Setting file ownership for postgres data to uid: ${POSTGRES_UID}"
sudo chown -R ${POSTGRES_UID} data
