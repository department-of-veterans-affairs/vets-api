# frozen_string_literal: true

module Veteran
  class FlagType < ActiveRecord::Type::Value
    VALID_TYPES = %w[email phone address other].freeze

    def valid_types
      VALID_TYPES
    end

    def cast(value)
      VALID_TYPES.include?(value) ? value : nil
    end
  end
end
