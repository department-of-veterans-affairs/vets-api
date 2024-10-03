# frozen_string_literal: true

module Preneeds
  class Race < Preneeds::Base
    ATTRIBUTE_MAPPING = {
      'I' => :is_american_indian_or_alaskan_native,
      'A' => :is_asian,
      'B' => :is_black_or_african_american,
      'H' => :is_spanish_hispanic_latino,
      'U' => :not_spanish_hispanic_latino,
      'P' => :is_native_hawaiian_or_other_pacific_islander,
      'W' => :is_white
    }.freeze

    ATTRIBUTE_MAPPING.each_value do |attr|
      attribute(attr, Bool, default: false)
    end

    def as_eoas
      return_val = []

      ATTRIBUTE_MAPPING.each do |k, v|
        if public_send(v)
          return_val << {
            raceCd: k
          }
        end
      end

      return_val
    end

    def self.permitted_params
      ATTRIBUTE_MAPPING.values
    end
  end
end
