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
        poa_data_object = gather_poa_data

        # call sidekiq job
      end

      private

      def gather_poa_data
        # Parallelize create_vnp_form and create_vnp_ptcpnt
        form_promise = Concurrent::Promise.execute do
          Datadog::Tracing.continue_trace!(trace_digest) do
            gather_read_all_veteran_representatve_data
          end
        end
      end

      def gather_read_all_veteran_representatve_data

      end
    end
  end
end