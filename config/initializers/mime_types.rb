# frozen_string_literal: true

# Add new mime types for use in respond_to blocks:

Mime::Type.register 'application/vnd.geo+json', :geojson
Mime::Type.register 'application/jwt', :jwt
