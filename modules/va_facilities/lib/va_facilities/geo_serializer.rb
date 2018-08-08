module VaFacilities
  class GeoSerializer

    def self.to_geojson(object)
      if object.respond_to?(:each)
        to_feature_collection(object)
      else
        to_feature(object)
      end
    end

    def self.to_feature_collection(collection)
      result = { "type" => "FeatureCollection" }
      features = []
      collection.each do |obj|
        features << to_feature(obj)
      end
      result["features"] = features
      result
    end

    def self.to_feature(object)
      result = { "type" => "Feature" }
      result["geometry"] = geometry(object)
      result["properties"] = properties(object)
      result
    end

    def self.geometry(object)
      { 
        "type" => "Point",
        "coordinates" => [ object.long, object.lat ]
      }
    end

    def self.properties(object)
      {
        "name" => object.name,
        "id" => id(object),
        "facility_type" => object.facility_type,
        "classification" => object.classification,
        "website" => object.website,
        "address" => object.address,
        "phone" => object.phone,
        "hours" => object.hours
      }
    end

    def self.id(object)
      "#{PREFIX_MAP[object.facility_type]}_#{object.unique_id}"
    end


    PREFIX_MAP = {
      'va_health_facility' => 'vha',
      'va_benefits_facility' => 'vba',
      'va_cemetery' => 'nca',
      'vet_center' => 'vc'
    }.freeze

  end
end
