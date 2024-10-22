# frozen_string_literal: true

require_relative '../configuration'

module Vye
  module DGIB
    module VerificationRecord
      class Configuration < Vye::DGIB::Configuration
        def service_name
          'DGIB/VerificationRecord'
        end

        def mock_enabled?
          Settings.dgi.vye.vets.mock || false
        end
      end
    end
  end
end
