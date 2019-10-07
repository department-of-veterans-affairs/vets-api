# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class DrivetimeBandClient < Common::Client::Base
    configuration Facilities::DrivetimeBandConfiguration

    def get_all_drivetime_bands(max_record_count)
      query_count = 0
      data_collector = []
      loop do
        params = build_params(query_count * max_record_count)
        response = perform(:get, "/arcgis2/rest/services/Portal/MonthlyVAST_TTB/FeatureServer/0/query?", params)
        data_collector += response.body
        break if response.body.length < max_record_count

        query_count += 1
      end
      data_collector
    end

    def build_params(offset)
      { where: "1=1", inSR: 4326, outSR: 4326, returnGeometry: true,
        returnCountOnly: false, outFields: '*', returnDistinctValues: false,
        orderByFields: 'Name', f: 'json', resultOffset: offset }
    end
  end
end
