# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class BadRequest < StandardError
          def initialize(errors)
            @errors = errors

            super
          end

          def errors
            errors_array = []
            @errors.each do |err|
              errors_array << {
                title: err[:title] || 'Bad Request',
                detail: err[:detail],
                status: status_code.to_s # LH standards want this be a string
              }
            end
            errors_array
          end

          def status_code
            400
          end
        end
      end
    end
  end
end
