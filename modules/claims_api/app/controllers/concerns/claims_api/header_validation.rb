# frozen_string_literal: true

require 'common/exceptions'

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
