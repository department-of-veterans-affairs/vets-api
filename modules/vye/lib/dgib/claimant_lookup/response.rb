# frozen_string_literal: true

require 'dgib/response'

module Vye
  module DGIB
    module ClaimantLookup
      class Response < Vye::DGIB::Response
        attribute :claimant_id, Integer

        def initialize(status, response = nil)
          attributes = { claimant_id: response.body['claimant_id'] }

          super(status, attributes)
        end
      end
    end
  end
end
