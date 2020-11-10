# frozen_string_literal: true

module AppealsApi
  module Concerns
    module JsonFormatValidation
      extend ActiveSupport::Concern

      included do
        def validate_json_format
          if request.body.class.name == 'Puma::NullIO' # testing string b/c NullIO class doesn't always exist
            render_body_is_not_a_hash_error request.body
            return
          end

          @json_body = JSON.parse request.body.string
          return if @json_body.is_a? Hash

          render_body_is_not_a_hash_error @json_body
        rescue JSON::ParserError
          render_body_is_not_a_hash_error request.body.string
        end

        def render_body_is_not_a_hash_error(body)
          status = 422
          error = {
            status: status,
            detail: "The request body isn't a JSON object: #{body.inspect}",
            source: false
          }
          render status: status, json: { errors: [error] }
        end
      end
    end
  end
end
