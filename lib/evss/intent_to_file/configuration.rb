# frozen_string_literal: true

module EVSS
  module IntentToFile
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-intenttofile-services-web/rest/intenttofile/v1"
      end

      def service_name
        'EVSS/IntentToFile'
      end
    end
  end
end
