#!/bin/bash
set -e

cd spec/dummy

# Wait for PostgreSQL
until PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB -c '\q'; do
  echo "Waiting for PostgreSQL to start..."
  sleep 1
done

echo "PostgreSQL started"

# Run migrations
bundle exec rake db:migrate

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"