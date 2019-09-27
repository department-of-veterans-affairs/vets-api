# frozen_string_literal: true

module Common
  # This is a custom type class for ensuring Time is always coerced as UTC first then RFC1123
  class HTTPDate < Virtus::Attribute
    def coerce(value)
      return nil if value.to_s.empty?
      return Time.parse(value).utc.httpdate if value.is_a?(String)

      value.httpdate
    end
  end
end
