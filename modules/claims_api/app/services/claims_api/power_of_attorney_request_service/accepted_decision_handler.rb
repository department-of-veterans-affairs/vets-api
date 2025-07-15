# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'
<<<<<<< HEAD
<<<<<<< HEAD
require 'bgs_service/vnp_ptcpnt_phone_service'
<<<<<<< HEAD

=======
>>>>>>> 265ee2cf48 (API-43735-gather-data-for-poa-accept-phone-3)
=======
>>>>>>> e1171e221b (API-43735-gather-data-for-poa-accept-2)
=======
>>>>>>> 31e3f06064 (API-43735-gather-data-for-poa-accept-2)

module ClaimsApi
  module PowerOfAttorneyRequestService
    class AcceptedDecisionHandler
      LOG_TAG = 'accepted_decision_handler'
      FORM_TYPE_CODE = '21-22'

<<<<<<< HEAD
<<<<<<< HEAD
      # rubocop:disable Metrics/ParameterLists
      def initialize(proc_id:, poa_code:, registration_number:, metadata:, veteran:, claimant: nil)
=======
      def initialize(proc_id:, poa_code:, metadata:, veteran:, claimant: nil)
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
        @proc_id = proc_id
        @poa_code = poa_code
        @registration_number = registration_number
=======
      # rubocop:disable Metrics/ParameterLists
      def initialize(proc_id:, poa_code:, representative_id:, metadata:, veteran:, claimant: nil)
        @proc_id = proc_id
        @poa_code = poa_code
        @representative_id = representative_id
>>>>>>> 1255e92ce7 (WIP)
        @metadata = metadata
        @veteran = veteran
        @claimant = claimant
      end
      # rubocop:enable Metrics/ParameterLists

      def call
<<<<<<< HEAD
        ClaimsApi::Logger.log(
          LOG_TAG, message: "Starting data gathering for accepted POA with proc #{@proc_id}."
        )

<<<<<<< HEAD
        data = gather_poa_data
        poa_auto_establishment_mapper(data)
=======
        data = gather_poa_data

        poa_auto_establishment_mappper(data)
>>>>>>> f17b72c882 (WIP)
=======
        # poa_auto_establishment_mapper(data)
>>>>>>> 0f0617637b (Tests veteran and claimant objects matching real records)
      end

      private

      def gather_poa_data
<<<<<<< HEAD
<<<<<<< HEAD
        veteran_data = gather_veteran_data

<<<<<<< HEAD
        read_all_data = gather_read_all_veteran_representative_data
        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

<<<<<<< HEAD
        data = veteran_data.merge!(read_all_data)
        data.merge!(vnp_find_addrs_data)

<<<<<<< HEAD
        data.merge!('registration_number' => @registration_number.to_s)
=======
        data.merge!('registration_number' => @representative_id.to_s)

>>>>>>> 4b90aaed80 (WIP)
        if @claimant.present?
          claimant_data = gather_claimant_data
          claimant_addr_data = gather_vnp_addrs_data('claimant')
          claimant_phone_data = gather_vnp_phone_data
=======
        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

        if @claimant_ptcpnt_id.present?
          claimant_addr_data = gather_vnp_addrs_data('claimant')
>>>>>>> 22498c8b77 (Cleans up variable usage)

          claimant_data.merge!(claimant_addr_data)
          claimant_data.merge!(claimant_phone_data)
          claimant_data.merge!('claimant_id' => @claimant.icn)

          data.merge!('claimant' => claimant_data)
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

=======
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
        read_all_data = gather_read_all_veteran_representative_data

        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

        data = veteran_data.merge!(read_all_data)
        data.merge!(vnp_find_addrs_data)

        data.merge!(registration_number: @representative_id)

        if @claimant.present?
          claimant_data = gather_claimant_data
          claimant_addr_data = gather_vnp_addrs_data('claimant')
          claimant_phone_data = gather_vnp_phone_data

          claimant_data.merge!(claimant_addr_data)
          claimant_data.merge!(claimant_phone_data)

          claimant_data.merge!(claimant_id: @claimant.icn)

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

<<<<<<< HEAD
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
<<<<<<< HEAD

      def poa_auto_establishment_mapper(data)
        type = determine_type
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::PoaAutoEstablishmentDataMapper.new(
          type:,
          data:,
          veteran: @veteran
        ).map_data
      end

      def determine_type
        if poa_code_in_organization?
          '2122'
        else
          '2122a'
        end
      end

      def poa_code_in_organization?
        ::Veteran::Service::Organization.find_by(poa: @poa_code).present?
<<<<<<< HEAD
=======
      def read_all_vateran_representative_records
        ClaimsApi::VeteranRepresentativeService
          .new(external_uid: @veteran.participant_id, external_key: @veteran.participant_id)
          .read_all_veteran_representatives(type_code: FORM_TYPE_CODE, ptcpnt_id: @veteran.participant_id)
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
      end

      def gather_read_all_veteran_representative_data
        records = read_all_vateran_representative_records
        # error if records nil
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ReadAllVeteranRepresentativeDataMapper.new(
          proc_id: @proc_id,
          records:
        ).call
=======
        read_all_data = gather_read_all_veteran_representative_data

        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

        if @claimant_ptcpnt_id.present?
          claimant_addr_data = gather_vnp_addrs_data('claimant')
=======
        read_all_data = gather_read_all_veteran_representative_data

        vnp_find_addrs_data = gather_vnp_addrs_data('veteran')

        if @claimant_ptcpnt_id.present?
<<<<<<< HEAD
          claimant_addr_data = gather_vnp_addrs_data(@claimant_ptcpnt_id, 'claimant')
>>>>>>> 31e3f06064 (API-43735-gather-data-for-poa-accept-2)
=======
          claimant_addr_data = gather_vnp_addrs_data('claimant')
>>>>>>> 56a1343d6f (API-43735-gather-data-for-poa-accept-2)

          read_all_data.merge!(claimant: claimant_addr_data)
        end

        read_all_data.merge!(veteran: vnp_find_addrs_data)
<<<<<<< HEAD
>>>>>>> e1171e221b (API-43735-gather-data-for-poa-accept-2)
      end

      # key is 'veteran' or 'claimant'
      def gather_vnp_addrs_data(key)
<<<<<<< HEAD
        ptcpnt_id = key == 'veteran' ? @veteran.participant_id : @claimant.participant_id
=======
        ptcpnt_id = key == 'veteran' ? @vet_ptcpnt_id : @claimant_ptcpnt_id
>>>>>>> 22498c8b77 (Cleans up variable usage)
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
=======
>>>>>>> 1255e92ce7 (WIP)
      end

      def gather_read_all_veteran_representative_data
        records = read_all_vateran_representative_records
        # error if records nil
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::ReadAllVeteranRepresentativeDataMapper.new(
          proc_id: @proc_id,
          records:
        ).call
=======
>>>>>>> 31e3f06064 (API-43735-gather-data-for-poa-accept-2)
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
<<<<<<< HEAD
=======
>>>>>>> 2d0b7b7aa2 (Merges in upstream, fixes conflicts and cleans up requests to match)
=======

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
>>>>>>> 31e3f06064 (API-43735-gather-data-for-poa-accept-2)
    end
  end
end
