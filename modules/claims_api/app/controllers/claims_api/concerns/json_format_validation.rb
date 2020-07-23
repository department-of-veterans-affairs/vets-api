# frozen_string_literal: true

module ClaimsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    included do
      def validate_json_format
        body = request.body
        begin
          @json_body = JSON.parse(body.string)
        rescue
          error = {
            errors: [
              {
                type: 'malformed',
                detail: "The payload body isn't valid JSON:API format",
                links: {
                  about: 'https://jsonapi.org/format/'
                }
              }
            ]
          }
          render json: error.to_json, status: 422
        end
      end
    end
  end
end
