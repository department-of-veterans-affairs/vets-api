# frozen_string_literal: true

require 'common/client/base'

module Facilities
  module DrivetimeBands
  # Core class responsible for api interface operations
    class Client < Common::Client::Base
      configuration Facilities::DrivetimeBands::Configuration

      def get_drivetime_bands(offset, limit)
        params = build_params(offset, limit)
        response = perform(:get, '/arcgis2/rest/services/Portal/MonthlyVAST_TTB/FeatureServer/0/query', params)
        Facilities::DrivetimeBands::Response.new(response.body).get_features
      end

      def build_params(offset, limit)
        { where: '1=1', inSR: 4326, outSR: 4326, returnGeometry: true,
          returnCountOnly: false, outFields: '*', returnDistinctValues: false,
          orderByFields: 'Name', f: 'json', resultOffset: offset, resultRecordCount: limit }
      end
    end
  end
end
