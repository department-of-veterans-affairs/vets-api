# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    class DecisionHandler
      def initialize(ptcpnt_id:, proc_id:, representative_id:)
        @ptcpnt_id = ptcpnt_id
        @proc_id = proc_id
        @representative_id = representative_id
      end

      def call
        poa_request = validate_ptcpnt_id!
        first_name = poa_request['claimantFirstName'].presence || poa_request['vetFirstName'] if poa_request

        send_declined_notification(ptcpnt_id: @ptcpnt_id, first_name:, representative_id: @representative_id)
      end

      private

      def manage_representative_service
        ClaimsApi::ManageRepresentativeService.new(external_uid: Settings.bgs.external_uid,
                                                   external_key: Settings.bgs.external_key)
      end

      def validate_ptcpnt_id!
        if @ptcpnt_id.blank?
          raise ::Common::Exceptions::ParameterMissing.new('ptcpntId',
                                                           detail: 'ptcpntId is required if decision is declined')
        end

        if @representative_id.blank?
          raise ::Common::Exceptions::ParameterMissing
            .new('representativeId', detail: 'representativeId is required if decision is declined')
        end

        res = manage_representative_service.read_poa_request_by_ptcpnt_id(ptcpnt_id: @ptcpnt_id)

        raise ::Common::Exceptions::Lighthouse::BadGateway if res.blank?

        poa_requests = Array.wrap(res['poaRequestRespondReturnVOList'])

        matching_request = poa_requests.find { |poa_request| poa_request['procID'] == @proc_id }

        detail = 'Participant ID/Process ID combination not found'
        raise ::Common::Exceptions::ResourceNotFound.new(detail:) if matching_request.nil?

        matching_request
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
