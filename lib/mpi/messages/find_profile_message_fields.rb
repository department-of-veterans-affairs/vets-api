# frozen_string_literal: true

module MPI
  module Messages
    # validates the fields used to find profile messages
    class FindProfileMessageFields
      attr_reader :missing_keys, :missing_values

      REQUIRED_FIELDS = %i[
        given_names
        last_name
        birth_date
        ssn
      ].freeze

      def initialize(profile)
        @profile = profile
      end

      def valid?
        @missing_keys.blank? && @missing_values.blank?
      end

      def validate
        @missing_keys = REQUIRED_FIELDS - @profile.keys
        @missing_values = REQUIRED_FIELDS.select { |key| @profile[key].nil? || @profile[key].blank? }
      end
    end
  end
end
