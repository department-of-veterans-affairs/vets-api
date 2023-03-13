# frozen_string_literal: true

module ClaimsApi
  module Error
    class TokenValidationError < StandardError
      def errors
        [
          {
            title: 'Not authorized',
            detail: 'Not authorized.'
          }
        ]
      end

      def status_code
        :unauthorized
      end
    end
  end
end
