# frozen_string_literal: true

module Common
  class ISO8601Time < Virtus::Attribute
    def coerce(value)
      return Time.iso8601(value) if value.is_a?(String)
    end
  end
end
