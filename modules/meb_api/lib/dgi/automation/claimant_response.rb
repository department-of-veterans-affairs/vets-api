# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Automation
      class ClaimantResponse < MebApi::DGI::Response
        attribute :claimant, Hash
        attribute :service_data, Hash, array: true

        def initialize(status, response = nil)
          attributes = {
            claimant: response.body['claimant'],
            service_data: response.body['service_data']
          }
          super(status, attributes)
        end
      end
    end
  end
end
