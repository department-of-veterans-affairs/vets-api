# frozen_string_literal: true

require 'dgib/configuration'

module Vye
  module DGIB
    module VerificationRecord
      class Configuration < Vye::DGIB::Configuration
        def service_name
          'DGIB/VerificationRecord'
        end
      end
    end
  end
end
