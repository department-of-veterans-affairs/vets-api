# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    module Utilities
      module Load
        class << self
          def time(value)
            ActiveSupport::TimeZone['UTC'].parse(value.to_s)
          end

          def boolean(value)
            # `else` => `nil`
            case value
            when 'Y'
              true
            when 'N'
              false
            end
          end
        end
      end

      module Dump
        class << self
          def time(value)
            value.iso8601
          end

          def boolean(value)
            # `else` => `nil`
            case value
            when true
              'Y'
            when false
              'N'
            end
          end
        end
      end
    end
  end
end
