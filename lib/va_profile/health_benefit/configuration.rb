# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module HealthBenefit
    class Configuration < VAProfile::Configuration
      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/health-benefit/health-benefit"
      end

      def service_name
        'VAProfile/HealhtBenefit'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.health_benefit.mock || false
      end
    end
  end
end
