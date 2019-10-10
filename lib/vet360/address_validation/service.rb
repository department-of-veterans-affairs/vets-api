# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def initialize
      end

      def candidate(address)
        begin
          res = perform(
            :post,
            'candidate',
            address.address_validation_req.to_json
          )
        rescue => e
          handle_error(e)
        end
        CandidateResponse.new(res.body)
      end
    end
  end
end
