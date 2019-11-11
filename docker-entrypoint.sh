#!/bin/bash -e

bundle check || bundle install --binstubs="${BUNDLE_PATH}/bin"

exec "$@"
