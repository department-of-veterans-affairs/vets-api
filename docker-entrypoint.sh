#!/bin/bash -e

# note this logic is duplicated in the Dockerfile for prod builds,
# if you make major alteration here, please check that usage as well

BUNDLED_WITH=$(awk '/BUNDLED WITH/{getline; print}' Gemfile.lock | xargs) gem install bundler -v "$BUNDLED_WITH"
bundle check 2> /dev/null || bundle install --jobs=4
bundle binstubs --all --path="${BUNDLE_APP_CONFIG}/bin"

exec "$@"

if [ -e  "./docker_debugging" ] ; then
  echo starting rake docker_debugging:setup
  rake docker_debugging:setup
fi

