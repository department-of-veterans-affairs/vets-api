# frozen_string_literal: true

require 'committee/validation_error'

module Committee
  class UnprocessableEntityError < Committee::ValidationError
    # Override status to return 422 for validation errors (more appropriate than 400)
    def status
      422
    end

    def error_body
      {
        errors: [
          {
            title: 'Unprocessable Entity',
            detail: message,
            code: '422',
            status: '422',
            source: 'Committee::Middleware::RequestValidation'
          }
        ]
      }
    end

    def render
      [
        status,
        { 'Content-Type' => 'application/json' },
        [JSON.generate(error_body)]
      ]
    end
  end
end
