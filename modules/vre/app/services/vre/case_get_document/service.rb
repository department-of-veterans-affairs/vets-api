# frozen_string_literal: true

module VRE
  module CaseGetDocument
    class Service < VRE::Service
      configuration VRE::CaseGetDocument::Configuration

      STATSD_KEY_PREFIX = 'api.res.case_get_document'
      SERVICE_UNAVAILABLE_ERROR = 'APNX-1-4187-000'

      def initialize(icn)
        super()
        raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

        @icn = icn
      end

      def get_document(document_params)
        payload = build_payload(document_params)
        send_to_res(payload: payload.to_json)
      rescue Common::Exceptions::BackendServiceException => e
        log_error(e)
        raise e unless service_unavailable?(e)
      end

      private

      def api_path
        'get-case-get-document'
      end

      def request_headers
        {
          'Appian-API-Key' => Settings.res.api_key,
          'Accept' => 'application/pdf'
        }
      end

      def build_payload(document_params)
        {
          icn: @icn,
          resCaseId: document_params[:res_case_id],
          documentType: document_params[:document_type]
        }
      end

      def log_error(e)
        message = e.original_body['errorMessageList'] || e.original_body['error']
        Rails.logger.error("Failed to retrieve Ch. 31 case document: #{message}", backtrace: e.backtrace)
      end

      def service_unavailable?(e)
        return false unless e.original_body['error'] == SERVICE_UNAVAILABLE_ERROR

        raise e.class.new('RES_CASE_GET_DOCUMENT_503', e.response_values)
      end
    end
  end
end
