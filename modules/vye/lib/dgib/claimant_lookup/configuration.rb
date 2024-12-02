# frozen_string_literal: true

require 'dgib/configuration'

module Vye
  module DGIB
    module ClaimantLookup
      class Configuration < Vye::DGIB::Configuration
        def service_name
          'DGIB/ClaimantLookup'
        end
      end
    end
  end
end
