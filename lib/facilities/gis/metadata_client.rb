# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class Gis
      class MetadataClient < Common::Client::Base
      configuration Facilities::Gis::MetadataConfiguration

      def get_metadata(facility_type)
        resp = perform(:get, "#{facility_type}/FeatureServer/0?", f: 'json')
        JSON.parse resp.body
      end
    end
  end
end
