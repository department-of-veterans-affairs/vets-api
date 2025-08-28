# frozen_string_literal: true

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = auto_claim&.form_data&.deep_symbolize_keys
        @fes_claim = {}
        @veteran_participant_id = auto_claim.auth_headers&.dig('va_eauth_pid')
        @transaction_id = auto_claim.auth_headers&.dig('va_eauth_service_transaction_id')
      end

      def map_claim
        validate_required_fields!

        wrap_in_request_structure
      end

      private

      def wrap_in_request_structure
        {
          data: {
            serviceTransactionId: @transaction_id,
            veteranParticipantId: @veteran_participant_id,
            claimantParticipantId: @veteran_participant_id,
            form526: {}
          }
        }
      end

      def validate_required_fields!
        if @veteran_participant_id.blank?
          raise ArgumentError, 'Missing veteranParticipantId - auth_headers do not contain valid participant ID'
        end
        if @transaction_id.blank?
          raise ArgumentError, 'Missing serviceTransactionId - auth_headers do not contain valid service transaction ID'
        end
      end
    end
  end
end
