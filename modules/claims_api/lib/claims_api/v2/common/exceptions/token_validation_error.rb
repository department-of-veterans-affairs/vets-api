# frozen_string_literal: true

module ClaimsApi
  module V2
    module Common
      module Exceptions
        class TokenValidationError < StandardError
          def initialize(error)
            @title = 'Not authorized'
            @source = error.errors[0].source
            @status = error.errors[0].status
            @detail = error.errors[0].detail

            super
          end

          def errors
            [
              {
                title: @title,
                detail: @detail,
                status: @status.to_s,
                source: {
                  pointer: @source
                }
              }
            ]
          end

          def status
            'not implmented'
          end

          def status_code
            @status || '401'
          end
        end
      end
    end
  end
end
