# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class UnprocessableEntity < StandardError
          def initialize(errors)
            @errors = { errors: [errors] }

            super
          end

          def errors
            errors_array = []
            @errors[:errors].flatten.each do |err|
              errors_array << {
                title: err[:title] || 'Unprocessable entity',
                detail: err[:detail],
                status: status_code.to_s # LH standards want this be a string
              }
            end
            errors_array
          end

          def status_code
            422
          end
        end
      end
    end
  end
end
