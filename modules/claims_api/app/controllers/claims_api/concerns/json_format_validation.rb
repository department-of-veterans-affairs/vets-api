# frozen_string_literal: true

module ClaimsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    included do
      def validate_json_format
        if request.body.class.name == 'Puma::NullIO' # testing string b/c NullIO class doesn't always exist
          render_payload_is_not_a_hash_error
          return
        end

        @json_body = JSON.parse(request.body.string)
        render_payload_is_not_a_hash_error unless @json_body.is_a? Hash
      rescue JSON::ParserError
        render_payload_is_not_a_hash_error
      end

      def render_payload_is_not_a_hash_error
        error = { type: 'malformed', detail: "The payload body isn't a JSON object" }
        render status: 422, json: { errors: [error] }
      end
    end
  end
end
