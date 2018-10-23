# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class ConfigurationIncreaseOnly < EVSS::DisabilityCompensationForm::Configuration
      def base_path
        "#{Settings.evss.url}/#{Settings.evss.service_name}/rest/form526/v1"
      end
    end
  end
end
