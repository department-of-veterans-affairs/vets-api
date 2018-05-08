# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class FacilitiesMetaDataServiceException < Common::Exceptions::BackendServiceException; end
  class MetadataClient < Common::Client::Base
    configuration Facilities::MetadataConfiguration
    use_service_exception FacilitiesMetaDataServiceException

    def get_metadata(facility_type)
      JSON.parse perform(:get, "#{facility_type}/FeatureServer/0?", f: 'json').body
    end
  end
end
