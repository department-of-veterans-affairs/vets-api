# frozen_string_literal: true

module ClaimsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    included do
      def validate_json_format
        @json_body = JSON.parse(request.body.string)
      rescue JSON::ParserError
        error = {
          errors: [
            {
              type: 'malformed',
              detail: "The payload body isn't valid JSON format"
            }
          ]
        }
        render json: error.to_json, status: 422
      end
    end
  end
end
