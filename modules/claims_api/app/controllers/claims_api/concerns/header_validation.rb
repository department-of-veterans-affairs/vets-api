# frozen_string_literal: true

require_dependency 'common/exceptions/internal/parameters_missing'
require_dependency 'common/exceptions/internal/unauthorized'

module ClaimsApi
  module HeaderValidation
    extend ActiveSupport::Concern

    included do
      def validate_headers(required_headers)
        missing_headers = required_headers.reject { |header| request.headers[header] }
        raise ::Common::Exceptions::ParametersMissing, missing_headers unless missing_headers.empty?
      end
    end
  end
end
