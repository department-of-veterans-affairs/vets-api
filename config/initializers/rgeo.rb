# frozen_string_literal: true

RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  config.default = RGeo::Geos.factory_generator
  config.register(RGeo::Geographic.spherical_factory(srid: 4326, uses_lenient_assertions: true),
                  geo_type: 'polygon', srid: 4326)
end
