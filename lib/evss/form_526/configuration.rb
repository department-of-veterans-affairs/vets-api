# frozen_string_literal: true

module EVSS
  module Form526
    class Configuration < EVSS::Configuration

      def base_path
        "#{Settings.evss.url}/wss-form526-services-web/rest/form526/vi"
      end

      def service_name
        'EVSS/Form526'
      end

    end
  end
end
