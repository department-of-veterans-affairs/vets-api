# frozen_string_literal: true

module Notifications
  module EnumSubjectValues
    extend ActiveSupport::Concern

    FORM_10_10EZ = 'form_10_10ez'
    DASH_HCA = 'dashboard_health_care_application_notification'

    class_methods do
      # Creates the ActiveRecord::Enum mappings between the attribute values and
      # their associated database integers.
      #
      # To add a new value, add it to the **end** of the hash, incrementing the integer.
      #
      # Do **NOT** remap any existing attributes or integers.
      #
      # @return [Hash]
      # @see https://api.rubyonrails.org/v5.2/classes/ActiveRecord/Enum.html
      #
      def subjects_mapped_to_database_integers
        {
          FORM_10_10EZ => 0,
          DASH_HCA => 1
        }.symbolize_keys
      end
    end
  end
end
