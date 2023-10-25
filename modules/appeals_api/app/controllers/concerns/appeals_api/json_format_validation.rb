# frozen_string_literal: true

module AppealsApi
  module JsonFormatValidation
    extend ActiveSupport::Concern

    included do
      # Note that a 422 status was returned for bad JSON in decision reviews,
      # but in segmented APIs we return 400 to comply with standards
      def validate_json_format(error_status = 422)
        # rubocop:disable Style/ClassEqualityComparison
        # testing string b/c NullIO class doesn't always exist
        if request.body.class.name == 'Puma::NullIO'
          render_body_is_not_a_hash_error(error_status)
          return
        end
        # rubocop:enable Style/ClassEqualityComparison

        @json_body = JSON.parse request.body.string
        return if @json_body.is_a? Hash

        render_body_is_not_a_hash_error(error_status)
      rescue JSON::ParserError
        render_body_is_not_a_hash_error(error_status)
      end

      def render_body_is_not_a_hash_error(status = 422)
        error = {
          code: '109',
          detail: "The request body isn't a JSON object",
          status: status.to_s,
          title: status == 422 ? 'Validation error' : 'Bad Request'
        }
        render status:, json: { errors: [error] }
      end

      # This exists only to facilitate the updated 400 error status in segmented APIs
      def validate_json_body
        validate_json_format(400)
      end
    end
  end
end
