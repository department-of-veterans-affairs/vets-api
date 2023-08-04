# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/disability'

module VAProfile
  module Disability
    class DisabilityResponse < VAProfile::Response
      attribute :rating, String

      def self.from(current_user, raw_response = nil)
        body = raw_response&.body
        rating = get_rating(body)

        new(
          raw_response&.status,
          rating: rating
        )
      end

      def self.get_rating(body)
        return nil unless body

        rating = body&.dig(
          'profile',
          'disability_rating',
          'combined_service_connected_rating_percentage'
        )

        VAProfile::Models::Disability.build_from(rating)
      end
    end
  end
end
