# frozen_string_literal: true

require 'claims_api/common/exceptions/standards_compliant/token_validation_error'
require 'claims_api/common/exceptions/standards_compliant/json_validation_error'
require 'claims_api/common/exceptions/standards_compliant/unprocessable_entity'
require 'claims_api/common/exceptions/standards_compliant/resource_not_found'

module ClaimsApi
  module V2
    module Error
      module StandardsCompliantErrorHandler
        def self.included(clazz) # rubocop:disable Metrics/MethodLength
          clazz.class_eval do
            rescue_from ::Common::Exceptions::TokenValidationError do |err|
              render_error(
                ::ClaimsApi::Common::Exceptions::StandardsCompliant::TokenValidationError.new(err)
              )
            end

            rescue_from ::Common::Exceptions::ResourceNotFound,
                        ::ClaimsApi::Common::Exceptions::StandardsCompliant::ResourceNotFound,
                        ::Common::Exceptions::Forbidden,
                        ::Common::Exceptions::Unauthorized,
                        ::Common::Exceptions::ValidationErrorsBadRequest,
                        ::Common::Exceptions::UnprocessableEntity,
                        ::ClaimsApi::Common::Exceptions::StandardsCompliant::UnprocessableEntity do |err|
                          render_error(err)
                        end
            rescue_from JsonSchema::JsonApiMissingAttribute do |err|
              render_json_error(
                ::ClaimsApi::Common::Exceptions::StandardsCompliant::JsonValidationError.new(err.to_json_api)
              )
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
end
