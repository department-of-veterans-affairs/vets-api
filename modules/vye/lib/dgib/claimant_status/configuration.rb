# frozen_string_literal: true

require 'dgib/configuration'

module Vye
  module DGIB
    module ClaimantStatus
      class Configuration < Vye::DGIB::Configuration
        def service_name
          'DGIB/ClaimantStatus'
        end
      end
    end
  end
end
