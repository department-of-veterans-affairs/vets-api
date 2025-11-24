# frozen_string_literal: true

Geocoder.configure(
  lookup: :nominatim, # OpenStreetMap Nominatim geocoding service (default)
  timeout: 5,
  units: :mi,
  http_headers: { 'User-Agent' => 'va.gov incomplete address validation' }
)
