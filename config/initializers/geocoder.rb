# frozen_string_literal: true

# Geocoder configuration for OpenStreetMap Nominatim service
#
# IMPORTANT: This uses the public Nominatim instance. Usage policy:
# - Max 1 request per second (enforced via job scheduling delays)
# - Requires valid User-Agent identifying the application
#
# See: https://operations.osmfoundation.org/policies/nominatim/
Geocoder.configure(
  lookup: :nominatim, # OpenStreetMap Nominatim geocoding service (default)
  timeout: 5,
  units: :mi,
  http_headers: { 'User-Agent' => 'va.gov incomplete address validation' }
)
