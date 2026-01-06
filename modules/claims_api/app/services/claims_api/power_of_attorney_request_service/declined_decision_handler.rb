# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class DeclinedDecisionHandler
      def initialize(ptcpnt_id:, proc_id:, representative_id:)
        @ptcpnt_id = ptcpnt_id
        @proc_id = proc_id
        @representative_id = representative_id
      end

      def call
        poa_request = fetch_and_validate_ptcpnt_request!
        first_name = extract_first_name(poa_request)

        send_declined_notification(ptcpnt_id: @ptcpnt_id, first_name:, representative_id: @representative_id)
      end

      private

      def fetch_and_validate_ptcpnt_request!
        validate_params!

        res = read_poa_request_by_ptcpnt_id
        validate_response!(res)

        matching_request = find_matching_request(res)
        raise_resource_not_found unless matching_request

        matching_request
      end

      def validate_params!
        raise_if_blank(@ptcpnt_id, 'ptcpntId')
        raise_if_blank(@representative_id, 'representativeId')
      end

      def raise_if_blank(value, name)
        return if value.present?

        raise ::Common::Exceptions::ParameterMissing.new(
          name, detail: "#{name} is required if decision is declined"
        )
      end

      def read_poa_request_by_ptcpnt_id
        manage_representative_service.read_poa_request_by_ptcpnt_id(ptcpnt_id: @ptcpnt_id)
      end

      def validate_response!(res)
        raise ::Common::Exceptions::Lighthouse::BadGateway if res.blank?
      end

      def find_matching_request(res)
        poa_requests = Array.wrap(res['poaRequestRespondReturnVOList'])
        poa_requests.find { |poa| poa['procID'] == @proc_id }
      end

      def raise_resource_not_found
        detail = 'Participant ID/Process ID combination not found'
        raise ::Common::Exceptions::ResourceNotFound.new(detail:)
      end

      def extract_first_name(poa_request)
        poa_request['claimantFirstName'].presence || poa_request['vetFirstName']
      end

      def manage_representative_service
        ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bep.external_uid,
                                                   external_key: Settings.bep.external_key)
      end

      def send_declined_notification(ptcpnt_id:, first_name:, representative_id:)
        return unless Flipper.enabled?(:lighthouse_claims_api_v2_poa_va_notify)

        lockbox = Lockbox.new(key: Settings.lockbox.master_key)
        encrypted_ptcpnt_id = Base64.strict_encode64(lockbox.encrypt(ptcpnt_id))
        encrypted_first_name = Base64.strict_encode64(lockbox.encrypt(first_name))

        ClaimsApi::VANotifyDeclinedJob.perform_async(encrypted_ptcpnt_id, encrypted_first_name, representative_id)
      end
    end
  end
end
