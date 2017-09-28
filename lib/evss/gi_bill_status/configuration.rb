# frozen_string_literal: true
module EVSS
  module GiBillStatus
    class Configuration < EVSS::Configuration
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def base_path
        BASE_URL
      end

      def service_name
        'EVSS/GiBillStatus'
      end
    end
  end
end
