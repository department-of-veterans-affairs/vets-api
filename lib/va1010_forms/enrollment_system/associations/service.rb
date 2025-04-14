# frozen_string_literal: true

require 'veteran_enrollment_system/base_service'
require 'veteran_enrollment_system/associations/configuration'

module VeteranEnrollmentSystem
  module Associations
    class Service
      configuration VeteranEnrollmentSystem::Associations::Configuration
    end
  end
end
