# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class UnprocessableEntity < StandardError
          def initialize(errors)
            @errors = errors

            super
          end

          def errors_array
            errors_array = []
            @errors.each do |err|
              errors_array << {
                title: err[:title] || 'Unprocessable entity',
                detail: err[:detail],
                status: err[:status].to_s, # LH standards want this be a string
                source: {
                  pointer: "data/attributes#{err[:source]}"
                }
              }
            end
            errors_array
          end

          def status
            'not implmented'
          end

          def status_code
            422
          end
        end
      end
    end
  end
end
