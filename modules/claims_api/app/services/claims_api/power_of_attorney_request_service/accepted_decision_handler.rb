# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'

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
        read_all_data = gather_read_all_veteran_representative_data

        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

        if @claimant_ptcpnt_id.present?
          claimant_addr_data = gather_vnp_addrs_data('claimant')

          read_all_data.merge!(claimant: claimant_addr_data)
        end

        read_all_data.merge!(veteran: vnp_find_addrs_data)
      end

      def read_all_vateran_representative_records
        ClaimsApi::VeteranRepresentativeService
          .new(external_uid: @vet_ptcpnt_id, external_key: @vet_ptcpnt_id)
          .read_all_veteran_representatives(type_code: FORM_TYPE_CODE, ptcpnt_id: @vet_ptcpnt_id)
      end

      def gather_read_all_veteran_representative_data
        records = read_all_vateran_representative_records
        # error if records nil
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ReadAllVeteranRepresentativeDataMapper.new(
          proc_id: @proc_id,
          records:
        ).call
      end

      # key is 'veteran' or 'claimant'
      def gather_vnp_addrs_data(key)
        ptcpnt_id = key == 'veteran' ? @vet_ptcpnt_id : @claimant_ptcpnt_id
        primary_key = @metadata.dig(key, 'vnp_mail_id')

        # error if primary_key nil
        res = ClaimsApi::VnpPtcpntAddrsService
              .new(external_uid: ptcpnt_id, external_key: ptcpnt_id)
              .vnp_ptcpnt_addrs_find_by_primary_key(id: primary_key)

        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntAddrsFindByPrimaryKeyDataMapper.new(
          record: res
        ).call
      end
    end
  end
end
