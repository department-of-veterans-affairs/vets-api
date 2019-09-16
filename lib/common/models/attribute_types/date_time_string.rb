# frozen_string_literal: true

module Common
  # Ensures that a string can be parsed to a valid DateTime
  class DateTimeString < Virtus::Attribute
    def coerce(value)
      value if value.is_a?(::String) && Time.parse(value).iso8601
    rescue ArgumentError
      nil
    end
  end
end
