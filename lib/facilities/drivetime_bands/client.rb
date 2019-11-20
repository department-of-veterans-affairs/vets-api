# frozen_string_literal: true

require 'common/client/base'

module Facilities
  module DrivetimeBands
    class DrivetimeBandDownloadError < StandardError
    end

    # Core class responsible for api interface operations
    class Client < Common::Client::Base
      configuration Facilities::DrivetimeBands::Configuration

      def get_drivetime_bands(offset, limit)
        params = build_params(offset, limit)
        response = perform(:get, '/arcgis2/rest/services/Portal/MonthlyVAST_TTB/FeatureServer/0/query', params)
        drivetime_band_response = Facilities::DrivetimeBands::Response.new(response.body)

        if drivetime_band_response.parsed_json.key?('error')
          raise Facilities::DrivetimeBands::DrivetimeBandDownloadError,
                "Error in request at offset #{offset} and limit #{limit}. Cause: #{drivetime_band_response.parsed_json['error']}"
        end

        drivetime_band_response.get_features
      end

      def build_params(offset, limit)
        { where: '1=1', inSR: 4326, outSR: 4326, returnGeometry: true,
          returnCountOnly: false, outFields: '*', returnDistinctValues: false,
          orderByFields: 'Name', f: 'json', resultOffset: offset, resultRecordCount: limit }
      end
    end
  end
end
