# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class BadGateway < StandardError
          def errors
            errors_array = []
            errors_array << {
              status: status_code.to_s, # LH standards want this be a string
              title: 'Bad gateway',
              detail: 'The server received an invalid or null response from an upstream server.'
            }
            errors_array
          end

          def status_code
            502
          end
        end
      end
    end
  end
end
