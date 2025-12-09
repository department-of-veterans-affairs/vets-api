# frozen_string_literal: true

# KEEP UNTIL Common::Client Removed

module Common
  # This is a custom type class for ensuring Time is always coerced as UTC
  class UTCTime < Virtus::Attribute
    def coerce(value)
      return nil if value.to_s.empty?
      return Time.parse(value).utc if value.is_a?(String)

      value.utc
    end
  end
end
