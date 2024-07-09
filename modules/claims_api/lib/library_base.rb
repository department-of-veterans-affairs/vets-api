# frozen_string_literal: true

require 'claims_api/claim_logger'
require 'custom_error'

module ClaimsApi
  class LibraryBase
    def handle_transaction(service, request_type)
      resp = client.method(request_type).call(service).body[:items]
      log_outcome_for_claims_api(service, 'success', resp)
      resp
    rescue => e
      detail = e.respond_to?(:original_body) ? e.original_body : e
      log_outcome_for_claims_api(service, 'error', detail)

      error_handler(e)
    end

    private

    def error_handler(error)
      ClaimsApi::CustomError.new(error).build_error
    end

    def log_outcome_for_claims_api(action, status, response)
      ClaimsApi::Logger.log(action,
                            detail: "#{action} #{status}: #{response}")
    end
  end
end
