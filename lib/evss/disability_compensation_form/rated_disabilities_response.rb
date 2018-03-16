# frozen_string_literal: true

require 'evss/response'

module EVSS
  module DisabilityCompensationForm
    class RatedDisabilitiesResponse < EVSS::Response

      def initialize(status, response = nil)
        if response
          attributes = {
          # figure out what attributes go here
          }
        end
        super(status, attributes)
      end
    end
  end
end
