# frozen_string_literal: true

require 'veteran_enrollment_system/base_configuration'

module VeteranEnrollmentSystem
  module Form1095B
    class Configuration < VeteranEnrollmentSystem::BaseConfiguration

      def self.api_key_path
        :form1095b
      end

      ##
      # @return [String] Base path for Form 1095-B enrollment API URLs.
      #
      def base_path
        "#{Settings.veteran_enrollment_system.host}:#{Settings.veteran_enrollment_system.port}"
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'VeteranEnrollmentSystem/'
      end
    end
  end
end
