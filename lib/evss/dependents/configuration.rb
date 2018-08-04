# frozen_string_literal: true

module EVSS
  module Dependents
    class Configuration < EVSS::Configuration
      def base_path
        "#{Settings.evss.url}/wss-686-services-web-2.6/rest/"
      end

      def service_name
        'EVSS/Dependents'
      end
    end
  end
end
