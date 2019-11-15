# frozen_string_literal: true

module VAOS
  # This is a custom type class for ensuring Time is always coerced as UTC
  class AppointmentTime < Virtus::Attribute
    def coerce(value)
      return nil if value.to_s.empty?
      return value.strftime('%m/%d/%Y %T') if value.is_a?(Time)

      if value.is_a?(String)
        return Time.zone.parse(value).strftime('%m/%d/%Y %T') if value.include?('-')
      end

      value
    end
  end
end
