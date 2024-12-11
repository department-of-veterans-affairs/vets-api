# frozen_string_literal: true

# TODO: Replace this to either use the app/controllers/concerns/exception_handling.rb or somethingj
# more similar to that.
#
# Builds standardized HTTP error responses for the Accredited Representative Portal.
# Used to maintain consistent error formatting across the application.
#
# @example
#   render HttpErrorResponseBuilder.error_response(:unauthorized)
#   # => { json: { errors: ['User is not authorized...'] }, status: :forbidden }
#
# @example
#   render HttpErrorResponseBuilder.error_response(:not_found)
#   # => { json: { errors: ['Resource not found'] }, status: :not_found }
#
module AccreditedRepresentativePortal
  class HttpErrorResponseBuilder
    def self.error_response(error_type)
      case error_type
      when :unauthorized
        {
          json: { errors: ['User is not authorized to perform the requested action'] },
          status: :forbidden
        }
      when :not_found
        {
          json: { errors: ['Resource not found'] },
          status: :not_found
        }
      end
    end
  end
end
