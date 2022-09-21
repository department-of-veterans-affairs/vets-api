#!/bin/bash -e

# note this logic is duplicated in the Dockerfile for prod builds,
# if you make major alteration here, please check that usage as well

bundle check || bundle install --binstubs="${BUNDLE_APP_CONFIG}/bin" --jobs=4

exec "$@"
