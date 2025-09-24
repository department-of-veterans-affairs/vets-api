# frozen_string_literal: true

module ClaimsApi
  module V1
    class DisabilityCompensationFesMapper
      def initialize(auto_claim)
        @auto_claim = auto_claim
        @data = get_auto_claim_data(auto_claim)
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

      def get_auto_claim_data(auto_claim)
        return {} unless auto_claim&.form_data
        data = auto_claim.form_data.deep_symbolize_keys
        process_disabilities(data)
      end

      def process_disabilities(data)
        return data unless data[:disabilities].is_a?(Array)
        
        secondaries = extract_secondary_disabilities(data)
        data[:disabilities] += secondaries_with_action_type(secondaries)
        data
      end

      def extract_secondary_disabilities(data)
        secondaries = []
        
        data[:disabilities].each_with_index do |disability, index|
          if disability[:secondaryDisabilities].present?
            secondaries.concat(disability[:secondaryDisabilities])
            # Remove secondaries from original disability
            data[:disabilities][index] = disability.except(:secondaryDisabilities)
          end
        end
        
        secondaries
      end

      def secondaries_with_action_type(secondaries)
        secondaries.map do |disability|
          disability.merge(disabilityActionType: 'NEW')
        end
      end

      def extract_claimant_participant_id
        @auto_claim.auth_headers.dig('dependent', 'participant_id')
      end
    end
  end
end
