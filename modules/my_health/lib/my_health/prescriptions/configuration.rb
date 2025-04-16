# frozen_string_literal: true

require 'rx/configuration'

module MyHealth
  module Prescriptions
    class Configuration < Rx::Configuration
      def service_name
        'MyHealth-Prescriptions'
      end
    end
  end
end
