# frozen_string_literal: true

require 'claims_api/common/exceptions/lighthouse/token_validation_error'
require 'claims_api/common/exceptions/lighthouse/json_validation_error'
require 'claims_api/common/exceptions/lighthouse/unprocessable_entity'
require 'claims_api/common/exceptions/lighthouse/invalid_field_value'
require 'claims_api/common/exceptions/lighthouse/resource_not_found'

module ClaimsApi
  module V2
    module Error
      module LighthouseErrorHandler
        def self.included(clazz) # rubocop:disable Metrics/MethodLength
          clazz.class_eval do
            rescue_from ::Common::Exceptions::Unauthorized,
                        ::Common::Exceptions::TokenValidationError do |err|
              render_error(
                ::ClaimsApi::Common::Exceptions::Lighthouse::TokenValidationError.new(err)
              )
            end

            rescue_from ::Common::Exceptions::ResourceNotFound,
                        ::ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound,
                        ::Common::Exceptions::Forbidden,
                        ::Common::Exceptions::ValidationErrorsBadRequest,
                        ::Common::Exceptions::UnprocessableEntity,
                        ::ClaimsApi::Common::Exceptions::Lighthouse::InvalidFieldValue do |err|
                          render_error(err)
                        end
            rescue_from ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity do |err|
              render_json_error(err)
            end
            rescue_from JsonSchema::JsonApiMissingAttribute do |err|
              render_json_error(
                ::ClaimsApi::Common::Exceptions::Lighthouse::JsonValidationError.new(err.to_json_api)
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
          render json: { errors: error.errors_array }, status: error.status_code
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
