#!/bin/bash -e

# note this logic is duplciated in the Dockerfile for prod builds,
# if you make major alteration here, please check that usage as well
bundle check || bundle install --binstubs="${BUNDLE_APP_CONFIG}/bin"

exec "$@"

if [ -e  "./startserver" ] ; then
  echo Starting the rails server!
  rails server --binding=0.0.0.0
fi

