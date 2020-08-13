# frozen_string_literal: true

module Preneeds
  class Race < Preneeds::Base
    ATTRIBUTE_MAPPING = {
      'I' => :is_american_indian_or_alaskan_native,
      'A' => :is_asian,
      'B' => :is_black_or_african_american,
      'H' => :is_spanish_hispanic_latino,
      'P' => :is_native_hawaiian_or_other_pacific_islander,
      'W' => :is_white
    }
    NOT_HISPANIC = 'U'

    attribute ATTRIBUTE_MAPPING['I'], Boolean
    attribute ATTRIBUTE_MAPPING['A'], Boolean
    attribute ATTRIBUTE_MAPPING['B'], Boolean
    attribute ATTRIBUTE_MAPPING['H'], Boolean
    attribute ATTRIBUTE_MAPPING['P'], Boolean
    attribute ATTRIBUTE_MAPPING['W'], Boolean

    def as_eoas
      return_val = []

      ATTRIBUTE_MAPPING.each do |k, v|
        if public_send(v)
          return_val << {
            raceCd: k
          }
        elsif k == 'H'
          return_val << {
            raceCd: NOT_HISPANIC
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
