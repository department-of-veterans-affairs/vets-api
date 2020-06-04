# frozen_string_literal: true

require_relative 'configuration'

module EVSS
  module DisabilityCompensationForm
    class ConfigurationIncreaseOnly < EVSS::DisabilityCompensationForm::Configuration
      # :nocov:
      def base_path
        "#{Settings.evss.url}/#{Settings.evss.service_name}/rest/form526/v1"
      end
      # :nocov:
    end
  end
end
