# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/disability'

module VAProfile
  module Disability
    class DisabilityResponse < VAProfile::Response
      attribute :disability_rating, VAProfile::Models::Disability

      def self.from(_, raw_response = nil)
        body = raw_response&.body
        disability_rating = get_rating(body)

        new(
          raw_response&.status,
          disability_rating: disability_rating
        )
      end

      def self.get_rating(body)
        return nil unless body

        combined_service_connected_rating_percentage = body&.dig(
          'profile',
          'disability_rating',
          'combined_service_connected_rating_percentage'
        )

        VAProfile::Models::Disability.build_disability_rating(
          combined_service_connected_rating_percentage
        )
      end
    end
  end
end
