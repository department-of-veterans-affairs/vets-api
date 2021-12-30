# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Status
      class StatusResponse < MebApi::DGI::Response
        attribute :claimant_id, Integer
        attribute :claim_service_id, Integer
        attribute :claim_status, String
        attribute :received_date, String

        def initialize(status, response = nil)
          attributes = {
            claimant_id: response&.body&.fetch('claimant_id'),
            claim_service_id: response&.body&.fetch('claim_service_id'),
            claim_status: response&.body&.fetch('claim_status'),
            confirmation_number: response&.body&.fetch('confirmation_number'),
            received_date: response&.body&.fetch('received_date')
          }

          super(status, attributes)
        end
      end
    end
  end
end
