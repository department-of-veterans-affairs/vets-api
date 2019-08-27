# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class GisMetadataClient < Common::Client::Base
    configuration Facilities::GisMetadataConfiguration

    def get_metadata(facility_type)
      resp = perform(:get, "#{facility_type}/FeatureServer/0?", f: 'json')
      JSON.parse resp.body
    end
  end
end
