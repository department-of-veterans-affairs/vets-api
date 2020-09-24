# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'

module Facilities
  module Metadata
    class Client < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      configuration Facilities::Metadata::Configuration

      STATSD_KEY_PREFIX = 'api.facilities_metadata'

      def get_metadata(facility_type)
        with_monitoring do
          JSON.parse perform(:get, "#{facility_type}/FeatureServer/0?", f: 'json').body
        end
      end
    end
  end
end
