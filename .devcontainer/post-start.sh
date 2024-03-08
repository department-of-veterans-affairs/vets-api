#!/bin/sh

docker-compose -f docker-compose-deps.yml up &

timeout 90 sh -c 'until pg_isready -h localhost -p 54320; do sleep 1; done'

bundle install
./bin/setup
