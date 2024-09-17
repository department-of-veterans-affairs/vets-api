# frozen_string_literal: true

require 'claims_api/common/exceptions/lighthouse/token_validation_error'
require 'claims_api/common/exceptions/lighthouse/json_validation_error'
require 'claims_api/common/exceptions/lighthouse/json_form_validation_error'
require 'claims_api/common/exceptions/lighthouse/backend_service_exception'
require './lib/common/exceptions/backend_service_exception'
require 'claims_api/common/exceptions/lighthouse/unprocessable_entity'
require 'claims_api/common/exceptions/lighthouse/resource_not_found'
require 'claims_api/common/exceptions/lighthouse/bad_request'
require 'claims_api/common/exceptions/lighthouse/bad_gateway'
require 'claims_api/common/exceptions/lighthouse/timeout'

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
                        ::ClaimsApi::Common::Exceptions::Lighthouse::BadRequest,
                        ::Common::Exceptions::BackendServiceException,
                        ::ClaimsApi::Common::Exceptions::Lighthouse::Timeout,
                        ::ClaimsApi::Common::Exceptions::Lighthouse::BadGateway,
                        ::ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException do |err|
                          render_non_source_error(err)
                        end

            rescue_from ::Common::Exceptions::Forbidden,
                        ::Common::Exceptions::ValidationErrorsBadRequest,
                        ::Common::Exceptions::UnprocessableEntity do |err|
                          render_error(err)
                        end
            rescue_from JsonSchema::JsonApiMissingAttribute do |err|
              render_json_errors(
                ::ClaimsApi::Common::Exceptions::Lighthouse::JsonValidationError.new(err.to_json_api)
              )
            end

            rescue_from ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity do |err|
              render_error(err)
            end
            rescue_from ::ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError do |errs|
              render_validation_errors(errs)
            end
          end
        end

        private

        def render_non_source_error(error)
          render json: {
            errors: error.errors.map do |e|
              error_hash = e.as_json.slice('status', 'title', 'detail')
              error_hash
            end
          }, status: error.status_code
        end

        def render_error(error)
          render json: {
            errors: error.errors.map do |e|
              error_hash = e.as_json.slice('title', 'status', 'detail')
              error_hash['source'] = format_source(error) unless error&.backtrace.nil?
              error_hash
            end
          }, status: error.status_code
        end

        def render_json_errors(error)
          if @claims_api_forms_validation_errors
            @claims_api_forms_validation_errors.concat(error.errors_array)
          else
            @claims_api_forms_validation_errors = error.errors_array
          end

          render json: { errors: @claims_api_forms_validation_errors }, status: error.status_code
        end

        def render_validation_errors(errors)
          render json: { errors: errors.errors_array }, status: errors.status_code
        end

        def format_source(error)
          { pointer: get_error_source(error) }
        end

        def get_error_source(error)
          full_backtrace = error&.backtrace&.[](0).to_s
          split_trace = full_backtrace.split('vets-api')
          return full_backtrace if split_trace.length == 1

          split_trace[1]
        end
      end
    end
  end
end
