# frozen_string_literal: true

require 'rx/configuration'

module MyHealth
  module Prescriptions
    # Configuration class for prescriptions
    class Configuration < Rx::Configuration
      # Override any Rx::Configuration settings if needed
      def service_name
        'MyHealth-Prescriptions'
      end
    end
  end
end
