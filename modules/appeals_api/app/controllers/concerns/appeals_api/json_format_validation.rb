# frozen_string_literal: true

module AppealsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    included do
      def validate_json_format
        # rubocop:disable Style/ClassEqualityComparison
        # testing string b/c NullIO class doesn't always exist
        if request.body.class.name == 'Puma::NullIO'
          render_body_is_not_a_hash_error request.body
          return
        end
        # rubocop:enable Style/ClassEqualityComparison

        @json_body = JSON.parse request.body.string
        return if @json_body.is_a? Hash

        render_body_is_not_a_hash_error @json_body
      rescue JSON::ParserError
        render_body_is_not_a_hash_error request.body.string
      end

      def render_body_is_not_a_hash_error(_)
        status = 422
        error = {
          code: '109',
          detail: "The request body isn't a JSON object",
          status: status.to_s,
          title: 'Validation error'
        }
        render status:, json: { errors: [error] }
      end
    end
  end
end
