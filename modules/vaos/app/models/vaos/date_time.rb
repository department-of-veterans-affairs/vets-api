# frozen_string_literal: true

module VAOS
  # This is a custom type class for ensuring Time is always coerced as UTC
  class DateTime < Virtus::Attribute
    def coerce(value)
      return nil if value.to_s.empty?
      return Time.parse(value).strftime('%D %T') if value.is_a?(String)

      value
    end
  end
end
