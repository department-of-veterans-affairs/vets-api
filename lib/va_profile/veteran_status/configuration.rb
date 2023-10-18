# frozen_string_literal: true

require 'va_profile/configuration'

module VAProfile
  module VeteranStatus
    class Configuration < VAProfile::Configuration
      self.read_timeout = 30

      def base_path
        "#{VAProfile::Configuration::SETTINGS.url}/profile-service/profile/v3"
      end

      def service_name
        'VAProfileVeteranStatus'
      end

      def mock_enabled?
        false
      end
    end
  end
end
