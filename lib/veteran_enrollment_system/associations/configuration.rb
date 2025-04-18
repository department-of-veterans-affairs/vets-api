# frozen_string_literal: true

require 'veteran_enrollment_system/base_configuration'

module VeteranEnrollmentSystem
  module Associations
    class Configuration < VeteranEnrollmentSystem::BaseConfiguration
      def self.api_key_path
        :associations
      end

      def base_path
        "#{Settings.veteran_enrollment_system.host}/ves-associate-gateway-svc/associations/person/"
      end
    end
  end
end
