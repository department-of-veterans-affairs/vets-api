# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Configuration < EVSS::Configuration

      def base_path
        "#{Settings.evss.url}/wss-form526-services-web/rest/form526/vi"
      end

      def service_name
        'EVSS/DisabilityCompensationForm'
      end

    end
  end
end
