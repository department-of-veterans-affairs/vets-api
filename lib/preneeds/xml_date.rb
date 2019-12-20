# frozen_string_literal: true

module Preneeds
  # This is a custom type class for `Virtus` attributes for ensuring Time is always coerced as UTC first then RFC1123
  #
  class XmlDate < Virtus::Attribute
    # @return [Time, nil] coerces value into Time value.
    #
    def coerce(value)
      return nil if value.to_s.empty?

      begin
        Time.iso8601(value&.to_s).utc.strftime('%Y-%m-%d')
      rescue ArgumentError
        value
      end
    end
  end
end
