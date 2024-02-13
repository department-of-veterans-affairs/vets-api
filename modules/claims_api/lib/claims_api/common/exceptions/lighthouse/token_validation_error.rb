# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class TokenValidationError < StandardError
          def initialize(error)
            @title = 'Not authorized'
            @status = error.errors[0].status
            @detail = error.errors[0].detail

            super
          end

          def errors
            [
              {
                title: @title,
                detail: @detail,
                status: @status.to_s # LH standards want this shown as a string
              }
            ]
          end

          def status
            'not implmented'
          end

          def status_code
            @status || 401
          end
        end
      end
    end
  end
end
