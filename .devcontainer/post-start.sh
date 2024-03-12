#!/bin/sh

# Start postgres & redis.
nohup bash -c 'docker-compose -f docker-compose-deps.yml up >> log/deps.log 2>&1 &'

bundle install
code --install-extension "Shopify.ruby-lsp"

# Wait for postgres to be ready before running setup.
timeout 90 sh -c 'until pg_isready -h localhost -p 54320; do sleep 1; done'
./bin/setup

nohup bash -c 'foreman start -m all=1,clamd=0,freshclam=0 >> log/foreman.log 2>&1 &'
