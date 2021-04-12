# frozen_string_literal: true

module ClaimsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    included do
      def validate_json_format
        if request.body.class.name == 'Puma::NullIO' # testing string b/c NullIO class doesn't always exist
          render_body_is_not_a_hash_error request.body
        end

        @json_body = JSON.parse request.body.string
        return if @json_body.is_a? Hash

        render_body_is_not_a_hash_error @json_body
      rescue JSON::ParserError
        render_body_is_not_a_hash_error request.body.string
      end

      def render_body_is_not_a_hash_error(body)
        message = "The request body isn't a JSON object: #{body.inspect}"
        raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
      end
    end
  end
end
