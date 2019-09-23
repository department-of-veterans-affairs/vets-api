# frozen_string_literal: true

require_dependency 'va_facilities/api_serialization'

module VaFacilities
  class GeoSerializer
    extend ApiSerialization

    def self.to_geojson(object)
      if object.respond_to?(:each)
        to_feature_collection(object)
      else
        to_feature(object)
      end
    end

    def self.to_feature_collection(collection)
      result = { 'type' => 'FeatureCollection' }
      features = []
      collection.each do |obj|
        features << to_feature(obj)
      end
      result['features'] = features
      result
    end

    def self.to_feature(object)
      result = { 'type' => 'Feature' }
      result['geometry'] = geometry(object)
      result['properties'] = properties(object)
      result
    end

    def self.geometry(object)
      {
        'type' => 'Point',
        'coordinates' => [object.long, object.lat]
      }
    end

    def self.properties(object)
      {
        'id' => id(object),
        'name' => object.name,
        'facility_type' => object.facility_type,
        'classification' => object.classification,
        'website' => object.website,
        'address' => object.address,
        'phone' => object.phone,
        'hours' => object.hours,
        'services' => services(object),
        'satisfaction' => satisfaction(object),
        'wait_times' => wait_times(object),
        'mobile' => object.mobile,
        'active_status' => object.active_status
      }
    end
  end
end
