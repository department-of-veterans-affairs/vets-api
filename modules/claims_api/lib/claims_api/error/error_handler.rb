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
        render json: {
          errors: error.errors.map do |e|
            error_hash = e.as_json.slice('title', 'status', 'detail')
            error_hash['source'] = format_source(e.source) unless e&.source.nil?
            error_hash
          end
        }, status: error.status_code
      end

      def format_source(err_source)
        { pointer: err_source.to_s }
      end

      # returns the file name and line number where the raise was called
      def get_source
        "#{File.basename(caller_locations.first.path)}:#{caller_locations.first.lineno}"
      end
    end
  end
end
