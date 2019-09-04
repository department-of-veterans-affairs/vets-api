# frozen_string_literal: true

module ClaimsApi
  module HeaderValidation
    extend ActiveSupport::Concern

    included do
      def validate_headers(required_headers)
        required_headers.each do |header|
          raise Common::Exceptions::ParameterMissing, header unless request.headers[header]
        end
      end
    end
  end
end
