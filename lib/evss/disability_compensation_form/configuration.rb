# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Configuration < EVSS::Configuration
      self.read_timeout = Settings.evss.disability_compensation_form.timeout || 55

      def base_path
        "#{Settings.evss.url}/#{Settings.evss.service_name}/rest/form526/v1"
      end

      def service_name
        'EVSS/DisabilityCompensationForm'
      end

      def mock_enabled?
        Settings.evss.mock_disabilities_form || false
      end
    end
  end
end
