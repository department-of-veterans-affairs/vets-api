# frozen_string_literal: true

require 'common/client/base'

module Facilities
  class DrivetimeBandDownloadError < StandardError
  end

  # Core class responsible for api interface operations
  class DrivetimeBandClient < Common::Client::Base
    configuration Facilities::DrivetimeBandConfiguration

    def get_drivetime_bands(offset, limit)
      params = build_params(offset, limit)
      response = perform(:get, '/arcgis2/rest/services/Portal/MonthlyVAST_TTB/FeatureServer/0/query', params)
      JSON.parse(response.body)['features']

      response_body = JSON.parse(response.body)

      if response_body.key?('error')
        raise Facilities::DrivetimeBandDownloadError,
              "Error in request at offset #{offset} and limit #{limit}. Cause: #{response_body['error']}"
      end

      response_body['features']
    end

    def build_params(offset, limit)
      { where: '1=1', inSR: 4326, outSR: 4326, returnGeometry: true,
        returnCountOnly: false, outFields: '*', returnDistinctValues: false,
        orderByFields: 'Name', f: 'json', resultOffset: offset, resultRecordCount: limit }
    end
  end
end
