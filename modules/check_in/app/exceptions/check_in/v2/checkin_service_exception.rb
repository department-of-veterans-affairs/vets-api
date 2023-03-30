# frozen_string_literal: true

module CheckIn
  module V2
    class CheckinServiceException < Common::Exceptions::BackendServiceException
      CIE_EXCEPTION_CODE = 'CIE-VETS-API_'

      def initialize(status:, original_body: {})
        super(CIE_EXCEPTION_CODE + status, response(status:, original_body:),
              status, original_body)
      end

      private

      def response(status:, original_body: {})
        {
          status:,
          detail: [original_body],
          code: CIE_EXCEPTION_CODE + status
        }
      end
    end
  end
end
