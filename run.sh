#!/bin/bash
source /etc/profile

echo "Waiting for database ${POSTGRES_HOST}:${POSTGRES_PORT} to become ready"
timeout 300 bash -c 'while [[ $(echo exit | socat - TCP:${POSTGRES_HOST}:${POSTGRES_PORT} &> /dev/null ; echo $?) -ne 0 ]]; do sleep 1; done' || exit 1
echo "Database has become ready"

# Clean out any lingering files from a previous run
rm -rf tmp

# Install any new Gems
bundle install

# Install the database if its not present
PGPASSWORD="${POSTGRES_PASSWORD}" psql -h postgres -U ${POSTGRES_USER} <<EOF | grep 'vets_api_development' &> /dev/null
\l
EOF
[[ $? -eq 1 ]] && bundle exec rake db:setup

# Run any migrations
bundle exec rake db:migrate

# Run main process
foreman start
