# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class DrivetimeBandClient < Common::Client::Base
    configuration Facilities::DrivetimeBandConfiguration

    def get_all_drivetime_bands(offset, limit)
      params = build_params(offset, limit)
      response = perform(:get, "/arcgis2/rest/services/Portal/MonthlyVAST_TTB/FeatureServer/0/query", params)
      # definitely should not have to parse like this 
      JSON.parse(response.body)['features']
    end

    def build_params(offset, limit)
      { where: "1=1", inSR: 4326, outSR: 4326, returnGeometry: true,
        returnCountOnly: false, outFields: '*', returnDistinctValues: false,
        orderByFields: 'Name', f: 'json', resultOffset: offset, resultRecordCount: limit }
    end
  end
end
