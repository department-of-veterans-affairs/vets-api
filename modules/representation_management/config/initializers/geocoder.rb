# frozen_string_literal: true

Geocoder.configure(
  lookup: :mapbox, # OpenStreetMap Nominatim geocoding service (default)
  timeout: 5,
  units: :mi,
  dataset: 'mapbox.places-permanent'
  # api_key: Settings.representation_management.geocoder.mapbox.api_key
)
