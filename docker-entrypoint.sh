#!/bin/bash -e

# note this logic is duplicated in the Dockerfile for prod builds,
# if you make major alteration here, please check that usage as well
chmod 777 /srv/vets-api/src/Gemfile.lock
bundle check || bundle install --binstubs="${BUNDLE_APP_CONFIG}/bin"

exec "$@"

if [ -e  "./docker_debugging" ] ; then
  echo starting rake docker_debugging:setup
  rake docker_debugging:setup
fi

