# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Forms
      class ClaimantResponse < MebApi::DGI::Response
        attribute :claimant, Hash
        attribute :toe_sponsors, Hash
        attribute :service_data, Hash, array: true

        def initialize(status, response = nil)
          attributes = {
            claimant: response.body['claimant'],
            toe_sponsors: response.body['toe_sponsors'],
            service_data: response.body['service_data']
          }
          super(status, attributes)
        end
      end
    end
  end
end
