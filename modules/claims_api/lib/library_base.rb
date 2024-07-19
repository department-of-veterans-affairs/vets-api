# frozen_string_literal: true

require 'claims_api/claim_logger'
require 'custom_error'

module ClaimsApi
  class LibraryBase
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
