# frozen_string_literal: true

require 'dgib/configuration'

module Vye
  module DGIB
    module VerifyClaimant
      class Configuration < Vye::DGIB::Configuration
        def service_name
          'DGIB/VerifyClaimant'
        end
      end
    end
  end
end
