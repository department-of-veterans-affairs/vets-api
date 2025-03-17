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

        poa_requests = ClaimsApi::PowerOfAttorneyRequest.where(proc_id: proc_ids).select(:id, :proc_id)
        poa_requests_by_proc_id = poa_requests.each_with_object({}) do |request, hash|
          hash[request.proc_id] = request.id
        end

        poa_list.map do |poa_request|
          proc_id = poa_request['procID']
          poa_request['id'] = poa_requests_by_proc_id[proc_id]

          poa_request
        end
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
        ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bgs.external_uid,
                                                   external_key: Settings.bgs.external_key)
      end
    end
  end
end
