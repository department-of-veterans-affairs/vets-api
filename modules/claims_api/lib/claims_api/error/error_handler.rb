# frozen_string_literal: true

require 'claims_api/common/exceptions/token_validation_error'

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
        end
      end

      private

      def render_error(error)
        render json: { errors: error.errors.map do |e|
                                 e.as_json.slice('title', 'detail')
                               end }, status: error.status_code
      end
    end
  end
end
