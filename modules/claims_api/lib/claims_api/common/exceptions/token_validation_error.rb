# frozen_string_literal: true

module ClaimsApi
  module Error
    class TokenValidationError < StandardError
      def errors
        [
          {
            title: 'Token Validation Error',
            detail: 'Invalid token.'
          }
        ]
      end

      def status_code
        :unauthorized
      end
    end
  end
end
