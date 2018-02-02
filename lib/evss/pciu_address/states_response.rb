# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIUAddress
    class StatesResponse < EVSS::Response
      attribute :states, Array[String]

      def initialize(status, response = nil)
        states = response&.body&.dig('cnp_states') || response&.body&.dig('states')
        super(status, states: states)
      end
    end
  end
end
