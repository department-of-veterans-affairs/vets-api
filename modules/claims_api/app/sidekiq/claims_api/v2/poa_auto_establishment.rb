require 'claims_api/v2/poa_data_service/read_all_veteran_representative_service'
require 'claims_api/v2/poa_data_service/vnp_pctpnt_addrs_find_by_primary_key_service'
require 'bgs_service/veteran_representative_service'
require 'bgs_service/vnp_ptcpnt_addrs_service'

module ClaimsApi
  module V2
    class PoaAutoEstablishment < ClaimsApi::ServiceBase
      def perform(proc_id, request_meta, vet_pctpnt_id, claimant_pctpnt_id=nil)
        @vet_pctpnt_id = vet_pctpnt_id
        @claimant_pctpnt_id = claimant_pctpnt_id

        @form_attributes = gather_data(proc_id)

      end

      private

      def gather_data(proc_id, form_type='21-22')
        read_all_response = ClaimsApi::VeteranRepresentativeService
                            .new(external_uid: @vet_pctpnt_id, external_key: @vet_pctpnt_id)
                            .read_all_veteran_representatives(type_code: form_type, ptcpnt_id: @vet_pctpnt_id)

        ra_data = read_all_service.data_object(proc_id, read_all_response)

        @form_type = set_form_type(ra_data)

        vet_find_addrs_response = ClaimsApi::VnpPtcpntAddrsService
                  .new(external_uid: @vet_pctpnt_id, external_key: @vet_pctpnt_id)
                  .vnp_ptcpnt_addrs_find_by_primary_key(id: '148886')

        vnp_addr_data = vnp_addrs_service.data_object(vet_find_addrs_response)

        if @claimant_pctpnt_id.present?
          claimant_find_addrs_response = ClaimsApi::VnpPtcpntAddrsService
            .new(external_uid: @claimant_pctpnt_id, external_key: @claimant_pctpnt_id)
            .vnp_ptcpnt_addrs_find_by_primary_key(id: '148886')

          claimant_addr_data = vnp_addrs_service.data_object(claimant_find_addrs_response)
        end
byebug
        ra_data.merge!(vnp_addr_data)
      end

      def set_form_type(data)
        poa_code = data[:poa_code]
        rep_fn = "John" # data[:representative_first_name]
        rep_ln = "Doe" # data[:representative_last_name]
        org_name = data[:organization_name]

        representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code)
                                                           .where(first_name: rep_fn, last_name: rep_ln)
                                                           .order(created_at: :desc)
                                                           .first
                                                           byebug

        # raise error if representative is nil
        determine_form_type(representative&.user_types&.first)
      end

      def determine_form_type(type)
        #raise if type nil?

        case type.downcase.gsub(' ', '')
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

      def read_all_service
        ClaimsApi::V2::ReadAllVeteranRepresentativeService.new
      end

      def vnp_addrs_service
        ClaimsApi::V2::VnpPctpntAddrsFindByPrimaryKeyService.new
      end
    end
  end
end