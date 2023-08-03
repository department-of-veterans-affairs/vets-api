# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module Disability
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.disability.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/profile-service/profile/v3"
      end

      def service_name  # Pretty sure on this. Check swagger docs.
        'VAProfile/Disability'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.disability.mock || false
      end
    end
  end
end
