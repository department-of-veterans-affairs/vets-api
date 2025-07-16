# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require 'bgs_service/vnp_ptcpnt_phone_service'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class AcceptedDecisionHandler
      FORM_TYPE_CODE = '21-22'

      def initialize(proc_id:, poa_code:, metadata:, veteran:, claimant: nil)
        @proc_id = proc_id
        @poa_code = poa_code
        @metadata = metadata
        @veteran = veteran
        @claimant = claimant
      end

      def call
        data = gather_poa_data

        poa_auto_establishment_mapper(data)
      end

      private

      def gather_poa_data
        veteran_data = gather_veteran_data

        read_all_data = gather_read_all_veteran_representative_data

        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

        data = veteran_data.merge!(read_all_data)
        data.merge!(vnp_find_addrs_data)

        if @claimant.present?
          claimant_data = gather_claimant_data
          claimant_addr_data = gather_vnp_addrs_data('claimant')
          claimant_phone_data = gather_vnp_phone_data

          claimant_data.merge!(claimant_addr_data)
          claimant_data.merge!(claimant_phone_data)

          data.merge!(claimant: claimant_data)
        end

        data
      end

      def gather_veteran_data
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VeteranDataMapper.new(
          veteran: @veteran
        ).call
      end

      def gather_claimant_data
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ClaimantDataMapper.new(
          claimant: @claimant
        ).call
      end

      def read_all_vateran_representative_records
        ClaimsApi::VeteranRepresentativeService
          .new(external_uid: @veteran.participant_id, external_key: @veteran.participant_id)
          .read_all_veteran_representatives(type_code: FORM_TYPE_CODE, ptcpnt_id: @veteran.participant_id)
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
        ptcpnt_id = key == 'veteran' ? @veteran.participant_id : @claimant&.participant_id

        primary_key = @metadata.dig(key, 'vnp_mail_id')

        # error if primary_key nil
        res = ClaimsApi::VnpPtcpntAddrsService
              .new(external_uid: ptcpnt_id, external_key: ptcpnt_id)
              .vnp_ptcpnt_addrs_find_by_primary_key(id: primary_key)

        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntAddrsFindByPrimaryKeyDataMapper.new(
          record: res
        ).call
      end

      def gather_vnp_phone_data
        primary_key = @metadata.dig('claimant', 'vnp_phone_id')

        res = ClaimsApi::VnpPtcpntPhoneService
              .new(external_uid: @claimant.participant_id, external_key: @claimant.participant_id)
              .vnp_ptcpnt_phone_find_by_primary_key(id: primary_key)

        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::VnpPtcpntPhoneFindByPrimaryKeyDataMapper.new(
          record: res
        ).call
      end

      def poa_auto_establishment_mapper(data)
        true
      end
    end
  end
end
