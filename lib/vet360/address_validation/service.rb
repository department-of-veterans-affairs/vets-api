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
        rescue Common::Client::Errors::ClientError => error
          save_error_details(error)
          raise_invalid_body(error, self.class) unless error.body.is_a?(Hash)

          raise Common::Exceptions::BackendServiceException.new(
            'VET360_AV_ERROR',
            {
              detail: error.body['messages']
            }
          )
        end

        CandidateResponse.new(res.body)
      end
    end
  end
end
