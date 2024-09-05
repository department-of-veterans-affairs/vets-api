# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class Orchestrator
      def initialize(veteran_participant_id, form_data, claimant_participant_id = nil, poa_key = :serviceOrganization)
        @veteran_participant_id = veteran_participant_id
        @form_data = form_data
        @claimant_participant_id = claimant_participant_id
        @poa_key = poa_key
      end

      def submit_request
        ClaimsApi::PowerOfAttorneyRequestService::TerminateExistingRequests.new(@veteran_participant_id).call
        ClaimsApi::PowerOfAttorneyRequestService::CreateRequest.new(@veteran_participant_id, @form_data,
                                                                    @claimant_participant_id, @poa_key).call
      end
    end
  end
end
