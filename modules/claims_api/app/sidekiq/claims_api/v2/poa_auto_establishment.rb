require 'claims_api/v2/poa_data_service/read_all_veteran_representative_service'
require 'claims_api/v2/poa_data_service/vnp_pctpnt_addrs_find_by_primary_key_service'
require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'

module ClaimsApi
  module V2
    class PoaAutoEstablishment < ClaimsApi::ServiceBase
      def perform(proc_id, poa_code, request_meta, vet_pctpnt_id, claimant_pctpnt_id=nil)
        @vet_pctpnt_id = vet_pctpnt_id
        @claimant_pctpnt_id = claimant_pctpnt_id
        @poa_code = poa_code
        @meta = request_meta

        form_attributes = gather_data(proc_id)

        # send form attributes to the next job which is PDF construction
      end

      private

      def gather_data(proc_id)
        read_all_data = gather_read_all_data(proc_id)
        @form_type = set_form_type(read_all_data)

        vnp_find_addrs_data = gather_vnp_addrs_data(@vet_pctpnt_id, 'veteran')

        if @claimant_pctpnt_id.present?
          claimant_find_addrs_response = gather_vnp_addrs_data(@claimant_pctpnt_id)
          claimant_addr_data = vnp_addrs_service.data_object(claimant_find_addrs_response, 'clamant')

          read_all_data.merge!(claimant_addr_data)
        end

        read_all_data.merge!(vnp_find_addrs_data)
      end

      def set_form_type(data)
        rep_fn = data[:representative_first_name]
        rep_ln = data[:representative_last_name]

        representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', @poa_code)
                                                           .where(first_name: rep_fn, last_name: rep_ln)
                                                           .order(created_at: :desc)
                                                           .first

        unless representative
          raise ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound.new(
            detail: "Could not retrieve Power of Attorney with code: #{@poa_code}"
          )
        end

        determine_form_type(representative&.user_types&.first)
      end

      def determine_form_type(type)
        case type&.downcase&.gsub(' ', '')
        when 'attorney'
          return '2122a'
        when 'claimsagent'
          return '2122a'
        when 'veteranserviceorganization(vso)'
          return '2122'
        else
          return '2122'
        end
      end

      def gather_read_all_data(proc_id)
        res = ClaimsApi::VeteranRepresentativeService
                            .new(external_uid: @vet_pctpnt_id, external_key: @vet_pctpnt_id)
                            .read_all_veteran_representatives(type_code: '21-22', ptcpnt_id: @vet_pctpnt_id)

        read_all_service.data_object(proc_id, res)
      end

      def read_all_service
        ClaimsApi::V2::ReadAllVeteranRepresentativeService.new
      end

      def gather_vnp_addrs_data(pctpnt_id, key)
        res = ClaimsApi::VnpPtcpntAddrsService
                  .new(external_uid: pctpnt_id, external_key: pctpnt_id)
                  .vnp_ptcpnt_addrs_find_by_primary_key(id: @meta["vnp_mailing_addr_id"])

        vnp_addrs_service.data_object(res, key)
      end

      def vnp_addrs_service
        ClaimsApi::V2::VnpPctpntAddrsFindByPrimaryKeyService.new
      end
    end
  end
end