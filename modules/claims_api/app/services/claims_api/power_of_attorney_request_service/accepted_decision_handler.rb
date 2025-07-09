# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class AcceptedDecisionHandler
      def initialize(ptcpnt_id:, proc_id:, poa_code:, metadata:, claimant_ptcpnt_id: nil)
        @vet_ptcpnt_id = ptcpnt_id
        @proc_id = proc_id
        @poa_code = poa_code
        @metadata = metadata
        @claimant_ptcpnt_id = claimant_ptcpnt_id
      end

      def call
      end
    end
  end
end