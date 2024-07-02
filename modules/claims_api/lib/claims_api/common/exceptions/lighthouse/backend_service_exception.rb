# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class BackendServiceException < StandardError
          def initialize(errors)
            @errors = [errors].flatten
            super
          end

          def errors
            errors_array = []
            @errors.each do |err|
              errors_array << {
                status: status_code.to_s, # LH standards want this be a string
                title: err[:title] || 'Backend Service Exception',
                detail: err[:detail] || err[:text]
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
