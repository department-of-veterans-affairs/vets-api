# frozen_string_literal: true

module ClaimsApi
  module Error
    class TokenValidationError < StandardError
      def errors
        [
          ::Common::Exceptions::SerializableError.new(
            title: 'Not authorized',
            detail: 'Not authorized.',
            status: '401',
            source: '/token_validation.rb:35'
          )
        ]
      end

      def status_code
        401
      end
    end
  end
end
