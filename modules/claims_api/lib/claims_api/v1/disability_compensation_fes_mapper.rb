# frozen_string_literal: true

# require_relative 'lighthouse_military_address_validator'

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      # include LighthouseMilitaryAddressValidator
      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @fes_claim = {}
      end

      def map_claim
        wrap_in_request_structure
      end

      private

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @auto_claim.auth_headers['va_eauth_service_transaction_id'],
            claimantParticipantId: extract_claimant_participant_id,
            form526: @fes_claim
          }
        }
      end

      def claim_attributes; end

      def extract_claimant_participant_id
        @auto_claim.auth_headers.dig('dependent', 'participant_id')
      end
    end
  end
end
