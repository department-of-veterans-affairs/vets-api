# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration Facilities::Configuration

    def get_all_facilities(facility_type, order_field, max_record_count)
      query_count = 0
      data_collector = []
      loop do
        params = build_params(order_field, (query_count * max_record_count))
        response = perform(:get, "#{facility_type}/FeatureServer/0/query?", params)
        data_collector += response.body
        break if response.body.length < max_record_count
        query_count += 1
      end
      data_collector
    end

    def build_params(order_field, offset)
      { where: '1=1', inSR: 4326, outSR: 4326, returnGeometry: true,
        returnCountOnly: false, outFields: '*', returnDistinctValues: false,
        orderByFields: order_field, f: 'json', resultOffset: offset }
    end
  end
end
