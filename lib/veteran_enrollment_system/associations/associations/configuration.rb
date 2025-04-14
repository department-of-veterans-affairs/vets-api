# frozen_string_literal: true

require 'veteran_enrollment_system/configuration'

module VeteranEnrollmentSystem
  module Associations
    module Associations
      class Configuration < VeteranEnrollmentSystem::BaseConfiguration
        ##
        # @return [Hash] The basic headers required for any VES Associations API call
        #
        def self.base_request_headers
          super.merge('apiKey' => Settings.veteran_enrollment_system.associations.api_key)
        end
      end
    end
  end
end
