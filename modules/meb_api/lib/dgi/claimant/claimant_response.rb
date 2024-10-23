# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Claimant
      class ClaimantResponse < MebApi::DGI::Response
        attribute :claimant_id, String

        def initialize(status, response = nil)
          attributes = {
            claimant_id: response&.body&.fetch('claimant_id', nil)
          }
          super(status, attributes)
        end
      end
    end
  end
end
