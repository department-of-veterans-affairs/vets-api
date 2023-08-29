# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module VeteranStatus
    class Configuration < VAProfile::Configuration
      self.read_timeout = VAProfile::Configuration::SETTINGS.disability.timeout || 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/profile-service/profile/v3"
      end

      def service_name
        # can verify through swagger docs
        'VAProfileVeteranStatus'
      end

      def mock_enabled?
        VAProfile::Configuration::SETTINGS.veteran_status.mock || false
      end
    end
  end
end
