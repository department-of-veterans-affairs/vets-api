# frozen_string_literal: true

module ClaimsApi
  module V2
    module JsonFormatValidation
      extend ActiveSupport::Concern

      included do
        def validate_json_format
          # rubocop:disable Style/ClassEqualityComparison
          # testing string b/c NullIO class doesn't always exist
          if request.body.class.name == 'Puma::NullIO'
            render_body_is_not_a_hash_error
            return
          end
          # rubocop:enable Style/ClassEqualityComparison

          @json_body = JSON.parse request.body.read
          return if @json_body.is_a? Hash

          render_body_is_not_a_hash_error
        rescue JSON::ParserError
          render_body_is_not_a_hash_error
        end

        def render_body_is_not_a_hash_error
          status = '422'
          error = {
            title: 'Unprocessable entity',
            status:,
            detail: "The request body isn't a JSON object."
          }
          render status:, json: { errors: [error] }
        end
      end
    end
  end
end
