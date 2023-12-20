# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module HealthBenefit
    class Configuration < VAProfile::Configuration
      def base_path
        "#{Settings.vet360.url}/health-benefit"
      end

      def service_name
        'VAProfile/HealhtBenefit'
      end

      def mock_enabled?
        Settings.vet360&.health_benefit&.mock || false
      end
    end
  end
end
