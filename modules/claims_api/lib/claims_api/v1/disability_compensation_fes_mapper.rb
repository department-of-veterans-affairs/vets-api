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
            veteranParticipantId: extract_veteran_participant_id,
            form526: @fes_claim
          }
        }
      end

      def claim_attributes
        # method calls
      end

      def extract_claimant_participant_id
        # For dependent claims, use dependent participant ID
        if @auto_claim.auth_headers&.dig('dependent', 'participant_id').present?
          @auto_claim.auth_headers.dig('dependent', 'participant_id')
        else
          # Otherwise, claimant is the veteran
          extract_veteran_participant_id
        end
      end

      def extract_veteran_participant_id
        # Try auth_headers first, then fall back to other sources
        # NOTE: veteran_icn is NOT a valid participant ID and would require BGS lookup
        @auto_claim.auth_headers&.dig('va_eauth_pid') ||
          @auto_claim.auth_headers&.dig('participant_id') ||
          @auto_claim.veteran_icn # fallback, would need BGS lookup to convert
      end
    end
  end
end
