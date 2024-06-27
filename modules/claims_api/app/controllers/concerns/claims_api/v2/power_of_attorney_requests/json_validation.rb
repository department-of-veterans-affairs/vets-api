# frozen_string_literal: true

module ClaimsApi
  module V2
    module PowerOfAttorneyRequests
      ##
      # = Recommended usage
      # Using a schema path derived directly from the API itself via the current
      # request's URI and method:
      #
      # ```
      #   before_action :validate_json!
      # ```
      #
      # This is probably the most principled approach because a request's URI,
      # method, and body almost totally comprise how an API's input is defined.
      #
      # For example, given a request like:
      #   `POST /v2/power-of-attorney-requests/:id/decision`
      # Then a schema path mirroring the API will be used:
      #   `/v2/power_of_attorney_requests/param/decision/post.json`
      #
      #
      # == Alternately, overriding the schema path
      #
      # ```
      #   before_action -> { validate_json!(schema_path: 'path/to/schema.json') }
      # ```
      #
      module JsonValidation
        extend ActiveSupport::Concern

        class SchemaLoadError < StandardError
          def initialize(path, reason)
            super <<~MSG.squish
              Failed to load schema
              at #{path}
              because it was #{reason}
            MSG
          end
        end

        private

        def validate_json!(schema_path: api_json_schema_path)
          @body =
            begin
              MultiJson.load(request.body.string)
            rescue MultiJson::ParseError
              detail = 'Malformed JSON in request body'
              raise ::Common::Exceptions::BadRequest, detail:
            end

          schema =
            begin
              path = Engine.root / Settings.claims_api.schema_dir / schema_path
              JSONSchemer.schema(path)
            rescue Errno::ENOENT
              raise SchemaLoadError.new(path, 'invalid')
            rescue JSON::ParserError
              raise SchemaLoadError.new(path, 'missing')
            end

          errors = schema.validate(@body).pluck('error')
          errors.empty? or
            raise ::Common::Exceptions::SchemaValidationErrors, errors
        end

        def api_json_schema_path
          path = request.route_uri_pattern.split('/')
          path.shift if path.first.blank?
          path.last.delete_suffix!('(.:format)')

          path.map! do |segment|
            next 'param' if segment.start_with?(':')

            segment.underscore
          end

          path << "#{request.method.underscore}.json"
          path.join('/')
        end
      end
    end
  end
end
