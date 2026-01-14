# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class Index
      def initialize(poa_codes:, page_size:, page_index:, filter: {})
        @poa_codes = poa_codes
        @page_size = page_size
        @page_index = page_index
        @filter = filter
      end

      def get_poa_list
        proc_ids = poa_list.pluck('procID')
        poa_requests = ClaimsApi::PowerOfAttorneyRequest.where(proc_id: proc_ids).select(:id, :proc_id, :claimant_icn)
        poa_requests_by_proc_id = build_list_hash(poa_requests)
        map_list_data(poa_requests_by_proc_id)
      end

      private

      def poa_list
        @poa_list ||= manage_representative_service.read_poa_request(poa_codes: @poa_codes,
                                                                     page_size: @page_size,
                                                                     page_index: @page_index,
                                                                     filter: @filter,
                                                                     use_mocks: true)
        list = @poa_list['poaRequestRespondReturnVOList']
        list.is_a?(Array) ? list : [list].compact
      end

      def manage_representative_service
        ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bep.external_uid,
                                                   external_key: Settings.bep.external_key)
      end

      # Returns a hash where proc_id is the key and the request record ID is the value
      def build_list_hash(poa_requests)
        poa_requests.each_with_object({}) do |request, hash|
          hash[request.proc_id] = { id: request.id, claimant_icn: request.claimant_icn }
        end
      end

      def map_list_data(poa_requests_by_proc_id)
        poa_list.map do |poa_request|
          proc_id = poa_request['procID']
          poa_request['id'] = poa_requests_by_proc_id[proc_id]&.dig(:id)
          poa_request['claimant_icn'] = poa_requests_by_proc_id[proc_id]&.dig(:claimant_icn)

          poa_request
        end
      end
    end
  end
end
