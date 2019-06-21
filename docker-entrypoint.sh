#!/bin/bash

set -e

bundle check || bundle install --binstubs="$BUNDLE_BIN"

exec "$@"
