# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class SharedClient < Common::Client::Base
    configuration Facilities::Configuration

    def get_all_facilities(facility_type, order_field)
      params = { where: '1=1', inSR: 4326, outSR: 4326, returnGeometry: true, returnCountOnly: false,
                 outFields: '*', returnDistinctValues: false, orderByFields: order_field, f: 'json' }
      perform(:get, "#{facility_type.gsub('Facilities::', '')}/FeatureServer/0/query?", params).body
    end
  end
end
