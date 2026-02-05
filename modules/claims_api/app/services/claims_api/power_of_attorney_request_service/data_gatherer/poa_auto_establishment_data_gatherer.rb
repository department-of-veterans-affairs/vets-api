# frozen_string_literal: true

require 'claims_api/v2/error/lighthouse_error_handler'
require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require 'bgs_service/vnp_ptcpnt_phone_service'
require_relative 'concerns/gatherer_utilities'

module ClaimsApi
  module PowerOfAttorneyRequestService
    module DataGatherer
      class PoaAutoEstablishmentDataGatherer
        include Concerns::GathererUtilities
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

          fetched_data = ClaimsApi::PowerOfAttorneyRequestService::DataGatherer::VnpPtcpntPhoneFindByPrimaryKeyDataGatherer.new(
            record: res
          ).call
          # If fetched_data errors out the BGS error handler will catch and raise it so
          # if we get here we got a response back, and since we know we have an ID by getting here
          # we can call this as expected, for backwards compatibility we only call this if we have
          # phone_data in metadata
          validate_phone_data(fetched_data['phone_nbr'], key) if @metadata.dig(key, 'phone_data').present?
          # Once we have validated the information from BGS matches our saved metadata for the phone number
          # we want to use the phone data we stored in the metadata object for the phone information on the form.
          # translate camel to snake case as well here to match rest of the object we send to the mapper in next step
          phone_data(key, fetched_data['phone_nbr'])
        end

        def claimant_icn
          @claimant.icn.presence || @claimant.mpi.icn
        end

        def validate_phone_data(fetched_phone_number, key)
          phone_metadata = @metadata.dig(key, 'phone_data')
          expected_phone = "#{phone_metadata&.dig('areaCode')}#{phone_metadata&.dig('phoneNumber')}"

          if expected_phone != fetched_phone_number
            raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
              detail: "Phone data mismatch for #{key}"
            )
          end
        end

        def phone_data(key, fetched_phone_number)
          phone_data = @metadata[key]
          if phone_data.key?('phone_data')
            phone_data['phone_data'].transform_keys(&:underscore)
          else
            country_code, area_code, phone_number = parse_phone_number(fetched_phone_number)

            {
              'country_code' => country_code || nil,
              'area_code' => area_code || nil,
              'phone_number' => phone_number || nil
            }
          end
        end
      end
    end
  end
end
