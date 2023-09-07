# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module HealthBenefit
    class Configuration < VAProfile::Configuration
      # override timeout
      # self.read_timeout = VAProfile::Configuration::SETTINGS.health_benefit.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/health-benefit/health-benefit"
      end

      def service_name
        'VAProfile/HealhtBenefit'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.health_benefit.mock || false
      end

      # set User-Agent request header
      # def user_agent; "vets-api"; end
    end
  end
end
