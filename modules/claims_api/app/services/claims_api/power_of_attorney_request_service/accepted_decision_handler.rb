# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class AcceptedDecisionHandler
      FORM_TYPE_CODE = '21-22'

      def initialize(ptcpnt_id:, proc_id:, poa_code:, metadata:, claimant_ptcpnt_id: nil)
        @vet_ptcpnt_id = ptcpnt_id
        @proc_id = proc_id
        @poa_code = poa_code
        @metadata = metadata
        @claimant_ptcpnt_id = claimant_ptcpnt_id
      end

      def call
        gather_poa_data

        # call sidekiq job
      end

      private

      def gather_poa_data
        records = read_all_vateran_representative_records

        gather_read_all_veteran_representative_data(records)
      end

      def gather_read_all_veteran_representative_data(records)
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ReadAllVeteranRepresentativeDataMapper.new(
          proc_id: @proc_id,
          records:
        ).call
      end

      def read_all_vateran_representative_records
        ClaimsApi::VeteranRepresentativeService
          .new(external_uid: @vet_ptcpnt_id, external_key: @vet_ptcpnt_id)
          .read_all_veteran_representatives(type_code: FORM_TYPE_CODE, ptcpnt_id: @vet_ptcpnt_id)
      end
    end
  end
end
