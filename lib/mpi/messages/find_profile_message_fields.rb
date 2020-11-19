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
        !(@missing_keys || @missing_values)
      end

      def validate
        @missing_keys = !REQUIRED_FIELDS.all? { |k| @profile.key?(k) }
        @missing_values = !REQUIRED_FIELDS.all? { |k| @profile[k].present? }
      end
    end
  end
end
