# frozen_string_literal: true

require 'claims_api/common/exceptions/token_validation_error'
require 'claims_api/common/exceptions/json_schema_validation_error'

module ClaimsApi
  module Error
    module ErrorHandler
      def self.included(clazz)
        clazz.class_eval do
          rescue_from ::Common::Exceptions::TokenValidationError,
                      with: lambda {
                        render_error(ClaimsApi::Error::TokenValidationError.new)
                      }
          rescue_from ::Common::Exceptions::ResourceNotFound,
                      ::Common::Exceptions::Forbidden,
                      ::Common::Exceptions::Unauthorized,
                      ::Common::Exceptions::ValidationErrorsBadRequest,
                      ::Common::Exceptions::UnprocessableEntity do |err|
                        render_error(err)
                      end
          rescue_from JsonSchema::JsonApiMissingAttribute do |err|
            render_json_error(ClaimsApi::Error::JsonSchemaValidationError.new(err.to_json_api))
          end
        end
      end

      private

      def render_error(error)
        render json: {
          errors: error.errors.map do |e|
            error_hash = e.as_json.slice('title', 'status', 'detail')
            error_hash['source'] = format_source(error) unless error&.backtrace.nil?
            error_hash
          end
        }, status: error.status_code
      end

      def render_json_error(error)
        render json: {
          errors: error.errors.map do |e|
            error_hash = e.as_json.slice('title', 'status', 'detail')
            error_hash['source'] = e[:source]
            error_hash
          end
        }, status: error.status_code
      end

      def format_source(error)
        { pointer: get_error_source(error) }
      end

      def get_error_source(error)
        error&.backtrace&.[](0).to_s
      end
    end
  end
end
