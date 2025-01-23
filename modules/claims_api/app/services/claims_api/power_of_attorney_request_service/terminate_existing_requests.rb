# frozen_string_literal: true

require 'bgs_service/veteran_representative_service'
require 'bgs_service/manage_representative_service'

module ClaimsApi
  module PowerOfAttorneyRequestService
    class TerminateExistingRequests
      DEFAULT_FIRST_NAME = 'vets-api'
      DEFAULT_LAST_NAME = 'vets-api'
      FORM_TYPE_CODE = '21-22'

      def initialize(veteran_participant_id)
        @veteran_participant_id = veteran_participant_id
      end

      def call
        mapped_requests = []
        requests = get_non_obsolete_requests
        requests.each do |request|
          mapped_requests << { proc_id: request['procId'],
                               representative: { first_name: DEFAULT_FIRST_NAME,
                                                 last_name: DEFAULT_LAST_NAME } }
        end

        mapped_requests.each do |request|
          set_to_obsolete(request)
        end
      end

      private

      def get_non_obsolete_requests
        ClaimsApi::VeteranRepresentativeService
          .new(external_uid: @veteran_participant_id, external_key: @veteran_participant_id)
          .read_all_veteran_representatives(type_code: FORM_TYPE_CODE, ptcpnt_id: @veteran_participant_id)
          .reject { |request| request['secondaryStatus'] == 'Obsolete' }
      end

      def set_to_obsolete(request)
        manage_representative_service.update_poa_request(representative: request[:representative],
                                                         proc_id: request[:proc_id])
      end

      def manage_representative_service
        @manage_representative_service ||= ClaimsApi::ManageRepresentativeService
                                           .new(external_uid: @veteran_participant_id,
                                                external_key: @veteran_participant_id)
      end
    end
  end
end
