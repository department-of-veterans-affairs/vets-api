#!/bin/sh

mkdir -p log

# Start postgres & redis.
if ! pg_isready -h localhost -p 54320; then
  nohup bash -c 'docker-compose -f docker-compose-deps.yml up >> log/deps.log 2>&1 &'
fi

bundle install

# Wait for postgres to be ready.
timeout 90 sh -c 'until pg_isready -h localhost -p 54320; do sleep 1; done'

./bin/setup

if ! curl -s http://localhost:3000|grep -q 'Welcome to the va.gov API'; then
  nohup bash -c 'foreman start -m all=1,clamd=0,freshclam=0 >> log/foreman.log 2>&1 &'
fi
