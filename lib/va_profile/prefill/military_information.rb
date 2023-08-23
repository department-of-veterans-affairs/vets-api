# frozen_string_literal: true

require 'hca/military_information'
require 'va_profile/disability/service'

module VAProfile
  module Prefill
    class MilitaryInformation
      PREFILL_METHODS = %w[
        is_va_service_connected
        compensable_va_service_connected
        va_compensation_type
      ].freeze

      # Disability ratings counted as lower
      LOWER_DISABILITY_RATINGS = [10, 20, 30, 40].freeze

      # Disability ratings counted as higher
      HIGHER_DISABILITY_RATING = 50

      attr_reader :disability_service

      def initialize(user)
        @disability_service = VAProfile::Disability::Service.new(user)
      end

      # @return [Boolean] true if veteran is paid for a disability
      #  with a high disability percentage
      #
      # Rubocop wants this method to be named va_service_connected? but is_va_service_connected
      # is the name of the method we're replacing.
      #
      # rubocop:disable Naming/PredicateName
      def is_va_service_connected
        combined_service_connected_rating_percentage >= HIGHER_DISABILITY_RATING
      end
      # rubocop:enable Naming/PredicateName

      # @return [Boolean] true if veteran is paid for a disability
      #  with a low disability percentage
      def compensable_va_service_connected
        LOWER_DISABILITY_RATINGS.include?(combined_service_connected_rating_percentage)
      end

      # @return [String] If veteran is paid for a disability, this method will
      #  return which type of disability it is: highDisability or lowDisability
      def va_compensation_type
        # while supporting fallback support for the old fields,
        # make a consistent number of calls to the properties to
        # support specs that will be removed or updated
        high_disability = is_va_service_connected
        low_disability = compensable_va_service_connected

        if high_disability
          'highDisability'
        elsif low_disability
          'lowDisability'
        end
      end

      private

      def combined_service_connected_rating_percentage
        disability_data.disability_rating.combined_service_connected_rating_percentage.to_i
      end

      def disability_data
        @disability_data ||= disability_service.get_disability_data
      end
    end
  end
end
