# frozen_string_literal: true

module ClaimsApi
  module HeaderValidation
    extend ActiveSupport::Concern

    included do
      def validate_headers(required_headers)
        missing_headers = required_headers.reject { |header| request.headers[header] }
        raise ::Common::Exceptions::Internal::ParametersMissing, missing_headers unless missing_headers.empty?
      end
    end
  end
end
