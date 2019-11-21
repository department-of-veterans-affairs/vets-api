# frozen_string_literal: true

require 'common/client/base'

module Facilities
  module Metadata
    class Client < Common::Client::Base
      configuration Facilities::Metadata::Configuration

      def get_metadata(facility_type)
        JSON.parse perform(:get, "#{facility_type}/FeatureServer/0?", f: 'json').body
      end
    end
  end
end