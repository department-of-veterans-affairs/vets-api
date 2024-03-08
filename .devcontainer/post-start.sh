#!/bin/sh

docker-compose -f docker-compose-deps.yml up &

# Give the dependencies time to start
sleep 10

bundle install
./bin/setup

make native-up &
