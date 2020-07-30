# frozen_string_literal: true

module ClaimsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    MALFORMED_JSON_RESPONSE = {
      status: 422,
      json: {
        errors: [
          {
            type: 'malformed',
            detail: "The payload body isn't valid JSON:API format",
            links: {
              about: 'https://jsonapi.org/format/'
            }
          }
        ]
      }.to_json
    }.freeze

    included do
      def validate_json_format
        if request.body.is_a?(Puma::NullIO)
          render MALFORMED_JSON_RESPONSE
          return
        end

        @json_body = JSON.parse(request.body.string)
      rescue JSON::ParserError
        render MALFORMED_JSON_RESPONSE
      end
    end
  end
end
