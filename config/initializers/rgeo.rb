# frozen_string_literal: true

RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # In order to download rings from PSSG (drivetime bands) and decode them into polygons,
  # we need to register this spherical factory. The 'uses_lenient_assertions' config here
  # is particularly important, since it removes a strict check for linear rings. This
  # allows it to process non-OGC compliant polygons.
  config.register(RGeo::Geographic.spherical_factory(srid: 4326, uses_lenient_assertions: true),
                  geo_type: 'polygon', srid: 4326)
end
