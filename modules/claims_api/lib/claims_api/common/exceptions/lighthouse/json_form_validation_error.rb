# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        # This class is specifically for handling the collected errors
        # from form 526 and POA validations
        class JsonFormValidationError < StandardError
          def initialize(errors)
            @errors = { errors: } # errors comes in as an array from the JSON validator

            super
          end

          def errors_array
            errors_array = []
            @errors[:errors].each do |err|
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
