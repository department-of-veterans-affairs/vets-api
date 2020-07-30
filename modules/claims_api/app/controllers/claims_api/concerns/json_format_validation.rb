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
    }

    included do
      def validate_json_format
        unless request.body.respond_to? :string
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
