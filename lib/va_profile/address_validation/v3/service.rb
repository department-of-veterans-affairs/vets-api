# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/exceptions'
require_relative 'configuration'
require_relative 'address_suggestions_response'
require 'va_profile/service'
require 'va_profile/stats'

module VAProfile
  module AddressValidation
    module V3
      # Wrapper for the VA profile address validation/suggestions API
      class Service < VAProfile::Service
        include Common::Client::Concerns::Monitoring

        STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.address_validation".freeze
        configuration VAProfile::AddressValidation::V3::Configuration

        def initialize; end

        # Get address suggestions and override key from the VA profile API
        # @return [VAProfile::AddressValidation::V3::AddressSuggestionsResponse] response wrapper around address
        #   suggestions data
        def address_suggestions(address)
          with_monitoring do
            address.address_pou = address.address_pou == 'RESIDENCE/CHOICE' ? 'RESIDENCE' : address.address_pou

            begin
              candidate_res = candidate(address)

              AddressSuggestionsResponse.new(candidate_res)
            rescue Common::Exceptions::BackendServiceException => e
              if Flipper.enabled?(:profile_validate_address_when_no_candidate_found) &&
                 candidate_address_not_found?(e)
                validate_res = validate(address)

                AddressSuggestionsResponse.new(validate_res, validate: true)
              else
                handle_error(e)
              end
            rescue => e
              handle_error(e)
            end
          end
        end

        # @return [Hash] raw data from VA profile address validation API including
        #   address suggestions, validation key, and address errors
        def candidate(address)
          res = perform(
            :post,
            'candidate',
            address.address_validation_req.to_json
          )

          res.body
        rescue => e
          handle_error(e)
        end

        def validate(address)
          res = perform(
            :post,
            'validate',
            address.address_validation_req.to_json
          )

          res.body
        rescue => e
          handle_error(e)
        end

        private

        def handle_error(error)
          raise error unless error.is_a?(Common::Client::Errors::ClientError)

          save_error_details(error)
          raise_invalid_body(error, self.class) unless error&.body.present? && error.body.is_a?(Hash)

          raise Common::Exceptions::BackendServiceException.new(
            'VET360_AV_ERROR',
            detail: error.body
          )
        end

        def candidate_address_not_found?(exception)
          details = exception.errors.map { |e| e.instance_variable_get('@detail') || e.detail } || []
          details.any? { |detail| detail['messages'].any? { |message| message['key'] == 'CandidateAddressNotFound' } }
        end
      end
    end
  end
end
