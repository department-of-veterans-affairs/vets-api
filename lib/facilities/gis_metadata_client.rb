# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class GISMetadataClient < Common::Client::Base
    configuration Facilities::GISMetadataConfiguration

    def get_metadata(facility_type)
      JSON.parse perform(:get, "#{facility_type}/FeatureServer/0?", f: 'json').body
    end
  end
end
