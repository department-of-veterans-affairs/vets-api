# frozen_string_literal: true

require 'committee/validation_error'

module Committee
  class UnprocessableEntityError < Committee::ValidationError
    def status
      422
    end

    def error_body
      {
        errors: [
          {
            title: 'Unprocessable Entity',
            detail: sanitize_detail,
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

    private

    # Removes actual user input values from error messages to prevent PII exposure.
    # We will make this more robust in the future, to give specific details about which
    # fields and values are causing the schema validation to fail.
    def sanitize_detail
      'Request did not conform to API schema.'
    end
  end
end
