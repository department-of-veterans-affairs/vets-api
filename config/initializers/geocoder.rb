# frozen_string_literal: true

# Geocoder configuration for OpenStreetMap Nominatim service
#
# IMPORTANT: This uses the public Nominatim instance. Usage policy:
# - Max 1 request per second (enforced via job scheduling delays)
# - Requires valid User-Agent identifying the application
#
# See: https://operations.osmfoundation.org/policies/nominatim/
Geocoder.configure(
  lookup: :mapbox, # OpenStreetMap Nominatim geocoding service (default)
  timeout: 5,
  units: :mi,
  dataset: 'mapbox.places-permanent'
  # api_key: Settings.DETERMINE_WHERE
)
