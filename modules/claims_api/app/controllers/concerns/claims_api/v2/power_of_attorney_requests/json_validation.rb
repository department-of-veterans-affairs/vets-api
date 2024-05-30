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
      #   `/v2/power_of_attorney_requests/param/decision/post/request.json`
      #
      #
      # == Alternatively, override the schema path
      # Overriding the schema path at the controller level could look like:
      #
      # ```
      #   before_action do
      #     validate_json!(
      #       schema_path: 'path/to/schema.json'
      #     )
      #   end
      # ```
      #
      # Overriding the schema path at the action level could look like:
      #
      # ```
      #   def create
      #     validate_json!(
      #       schema_path: 'path/to/schema.json'
      #     )
      #   end
      # ```
      #
      # TODO: Add tests.
      #
      module JsonValidation
        extend ActiveSupport::Concern

        class Error < StandardError
          class BodyParseError < self
            def initialize
              super("The request body isn't a JSON object")
            end
          end

          class InvalidBodyError < self
            def initialize(errors)
              super(errors.pluck('error').join(', '))
            end
          end

          class SchemaNotFoundError < self
            def initialize(path)
              super <<~MSG
                Schema not found at #{path}
                If the file exists, make sure it is a valid schema
              MSG
            end
          end
        end

        included do
          rescue_from(Error::BodyParseError, Error::InvalidBodyError) do |error|
            # TODO: Reconsider error handling.
            error = ::Common::Exceptions::BadRequest.new(detail: error.message)
            render_error(error)
          end
        end

        private

        def validate_json!(schema_path: api_json_schema_path)
          schema =
            SCHEMAS.fetch(schema_path) do
              raise Error::SchemaNotFoundError, schema_path
            end

          @body = begin
            JSON.parse(request.body.string)
          rescue JSON::ParserError
            ''
          end

          @body.is_a?(Hash) or
            raise Error::BodyParseError

          errors = schema.validate(@body).to_a
          errors.empty? or
            raise Error::InvalidBodyError, errors
        end

        def api_json_schema_path
          path = request.route_uri_pattern.split('/')
          path.last.delete_suffix!('(.:format)')

          path.map! do |segment|
            next 'param' if segment.start_with?(':')

            segment.underscore
          end

          path << request.method.underscore
          path << 'request.json'
          path.join('/')
        end

        SCHEMAS =
          {}.tap do |schemas|
            base = Engine.root.join(Settings.claims_api.schema_dir)
            glob = base.join('**/*.json')

            Dir.glob(glob).each do |path|
              schema = JSONSchemer.schema(Pathname(path))
              path = path.delete_prefix(base.to_s)

              schemas[path] = schema
            rescue => e
              Rails.logger.warn(e)
            end

            schemas.freeze
          end
      end
    end
  end
end
