# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require 'bgs_service/vnp_ptcpnt_phone_service'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataGatherer
      class PoaAutoEstablishmentDataGatherer
        LOG_TAG = 'poa_auto_establishment_data_gatherer'
        FORM_TYPE_CODE = '21-22'

        def initialize(proc_id:, registration_number:, metadata:, veteran:, claimant: nil)
          @proc_id = proc_id
          @registration_number = registration_number
          @metadata = metadata
          @veteran = veteran
          @claimant = claimant
        end

        def gather_data
          ClaimsApi::Logger.log(
            LOG_TAG, message: "Starting data gathering for accepted POA with proc #{@proc_id}."
          )

          gather_poa_data
        end

        private

        def gather_poa_data
          data = gather_read_all_veteran_representative_data
          vnp_find_addrs_data = gather_vnp_addrs_data('veteran')
          vnp_find_phone_data = gather_vnp_phone_data('veteran')

          data.merge!(vnp_find_addrs_data)
          data.merge!(vnp_find_phone_data)

          data.merge!('registration_number' => @registration_number.to_s)
          if @claimant.present?
            claimant_addr_data = gather_vnp_addrs_data('claimant')

            if @metadata['claimant'].key?('vnp_phone_id')
              claimant_phone_data = gather_vnp_phone_data('claimant')
              claimant_addr_data.merge!(claimant_phone_data)
            end

            claimant_addr_data.merge!(claimant_addr_data)
            claimant_addr_data.merge!('claimant_id' => claimant_icn)

            data.merge!('claimant' => claimant_addr_data)
          end

          data
        end

        def read_all_veteran_representative_records
          ClaimsApi::VeteranRepresentativeService
            .new(external_uid: @veteran.participant_id, external_key: @veteran.participant_id)
            .read_all_veteran_representatives(type_code: FORM_TYPE_CODE, ptcpnt_id: @veteran.participant_id)
        end

        def gather_read_all_veteran_representative_data
          records = read_all_veteran_representative_records

          ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::ReadAllVeteranRepresentativeDataGatherer.new(
            proc_id: @proc_id,
            records:
          ).call
        end

        # key is 'veteran' or 'claimant'
        def gather_vnp_addrs_data(key)
          ptcpnt_id = key == 'veteran' ? @veteran.participant_id : @claimant&.participant_id
          primary_key = @metadata.dig(key, 'vnp_mail_id')

          res = ClaimsApi::VnpPtcpntAddrsService
                .new(external_uid: ptcpnt_id, external_key: ptcpnt_id)
                .vnp_ptcpnt_addrs_find_by_primary_key(id: primary_key)

          ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::VnpPtcpntAddrsFindByPrimaryKeyDataGatherer.new(
            record: res
          ).call
        end

        # key is 'veteran' or 'claimant'
        def gather_vnp_phone_data(key)
          ptcpnt_id = key == 'veteran' ? @veteran.participant_id : @claimant&.participant_id
          primary_key = @metadata.dig(key, 'vnp_phone_id')

          res = ClaimsApi::VnpPtcpntPhoneService
                .new(external_uid: ptcpnt_id, external_key: ptcpnt_id)
                .vnp_ptcpnt_phone_find_by_primary_key(id: primary_key)

          ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::VnpPtcpntPhoneFindByPrimaryKeyDataGatherer.new(
            record: res
          ).call
        end

        def claimant_icn
          @claimant.icn.presence || @claimant.mpi.icn
        end
      end
    end
  end
end
