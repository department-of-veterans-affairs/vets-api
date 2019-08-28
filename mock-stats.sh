#!/bin/bash -e

# This script will run until canceled, submitting stats to the statsd backend for scraping by prometheus
cleanup ()
{
  kill -s SIGTERM $!
  exit 0
}

trap cleanup SIGINT SIGTERM

# These are pulled from devops/ansible/deployment/config/vets-api/statsd-exporter-mapping.conf
#
# TODO: Maybe make this more useful by adding some variance, i.e.:
# declare -a buckets=("api.external_http_request" "api.external_service" "shared.sidekiq")
# declare -a types=("external_http_request" "external_service")
# declare -a states=("success" "failed" "skipped")
#  # ... etc

main () {
  while [ 1 ]
  do
     echo "reporting a statistic...";
     echo -n "api.external_http_request.vet360.success:1" | nc -w 1 -u 127.0.0.1 8125;
  done
}

main()
