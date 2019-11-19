require 'pp'

# frozen_string_literal: true

module Vet360
  module AddressValidation
    class Service < Vet360::Service
      configuration Vet360::AddressValidation::Configuration

      def initialize; end

      def address_suggestions(address)
        validate_res = validate(address)
        candidate_res = candidate(address)

        # go through messages here first and check for errors
        # pp validate_res
        # pp candidate_res
        validation_key = validate_res['address_meta_data']['validation_key']

        validate_messages = validate_res['messages'] || []
        pp validate_messages
        validate_messages.each do |message|
          if message['severity'] == 'ERROR'
            validation_key = nil
          end
        end
        # binding.pry

        AddressSuggestionsResponse.new(candidate_res, validation_key)

        # double check with vet360 to make sure that that's accurate
        # test this in staging (via SSH), not dev
        # AddressSuggestionsResponse.new(candidate_res, nil) <- removing validation_key
      end

      %w[validate candidate].each do |endpoint|
        define_method(endpoint) do |address|
          begin
            res = perform(
              :post,
              endpoint,
              address.address_validation_req.to_json
            )
          rescue => e
            handle_error(e)
          end

          res.body
        end
      end

      private

      def handle_error(error)
        raise error unless error.is_a?(Common::Client::Errors::ClientError)

        save_error_details(error)
        raise_invalid_body(error, self.class) unless error.body.is_a?(Hash)

        # error.body['messages']
        # if there are fatal errors, make
        # in the meeting tomorrow, ask more questions about the responses that vets360 will give
        # - verify "if i check the messages hash and the severity is 'ERROR', is that all that's required?"
        # - aka "how do I know that I can overwrite an error"

        raise Common::Exceptions::BackendServiceException.new(
          'VET360_AV_ERROR',
          detail: error.body
        )
      end
    end
  end
end
