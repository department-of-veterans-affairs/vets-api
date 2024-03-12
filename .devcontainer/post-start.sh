#!/bin/sh

nohup bash -c 'docker-compose -f docker-compose-deps.yml up >> log/deps.log 2>&1 &'

timeout 90 sh -c 'until pg_isready -h localhost -p 54320; do sleep 1; done'

bundle install
./bin/setup

nohup bash -c 'foreman start -m all=1,clamd=0,freshclam=0 >> log/foreman.log 2>&1 &'
