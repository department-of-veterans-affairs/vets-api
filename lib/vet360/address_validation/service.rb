# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def initialize
      end

      def validate(address)
        begin
          res = perform(
            :post,
            'validate',
            address.address_validation_req.to_json
          )
        rescue => error
          handle_error(error)
        end

        res
      end

      def candidate(address)
        begin
          res = perform(
            :post,
            'candidate',
            address.address_validation_req.to_json
          )
        rescue => error
          handle_error(error)
        end

        CandidateResponse.new(res.body)
      end

      private

      def handle_error(error)
        raise error unless error.is_a?(Common::Client::Errors::ClientError)

        save_error_details(error)
        raise_invalid_body(error, self.class) unless error.body.is_a?(Hash)

        raise Common::Exceptions::BackendServiceException.new(
          'VET360_AV_ERROR',
          {
            detail: error.body
          }
        )
      end
    end
  end
end
