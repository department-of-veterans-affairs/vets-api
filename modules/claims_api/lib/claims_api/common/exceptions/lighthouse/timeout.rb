# frozen_string_literal: true

module ClaimsApi
  module Common
    module Exceptions
      module Lighthouse
        class Timeout < StandardError
          def errors
            errors_array = []
            errors_array << {
              status: status_code.to_s, # LH standards want this be a string
              title: 'Upstream timeout',
              detail: 'An upstream service timed out.'
            }
            errors_array
          end

          def status_code
            504
          end
        end
      end
    end
  end
end
